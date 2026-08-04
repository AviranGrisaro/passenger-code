import CoreLocation
import Foundation
import MapKit

/// A minimal seam so `RoutePreviewModel` can be unit-tested against a
/// scripted authorization status (TRD §9 row 6) without touching
/// `Location/LocationStore.swift` — the TRD lists that file as "read, not
/// re-derived" (TRD header). `LocationStore` already exposes exactly this
/// property; this is a retroactive conformance declared here, not an edit to
/// its own file. Mirrors the `SavedPlacesPersisting`/`EventsFetching`
/// protocol-seam pattern already used elsewhere in this codebase.
protocol LocationAuthorizing: Sendable {
    @MainActor var authorizationStatus: CLAuthorizationStatus { get }
}

extension LocationStore: LocationAuthorizing {}

/// Owns resolve + selection for ONE place-modal presentation (TRD §4.4,
/// A2). Created by `PlaceDetailModal`'s `.task(id: place.id)`, torn down on
/// dismiss. Holds **no** state across places — the session memo that must
/// survive a dismissal lives in `RouteMemoStore` instead (§4.7, A2).
@MainActor
@Observable
final class RoutePreviewModel {
    private(set) var preview: RoutePreview = .idle
    private(set) var selection: RouteKind = .fast

    private let provider: any WalkingRouteProvider
    private let memo: RouteMemoStore
    /// Read once per `resolve()`, not held — the gate is authorization at
    /// the moment resolution starts (TRD §4.3's pseudocode), not a live
    /// subscription this model needs to react to mid-resolve.
    private let locationStore: any LocationAuthorizing

    /// Both `provider` and `memo` are injected, neither created here: the
    /// provider so tests can script it, the memo store because it must
    /// outlive this object (A2). `locationStore` is injected for the same
    /// reason `PermissionPrompt` takes one — §4.3's authorization gate reads
    /// it directly, and this model never constructs its own.
    init(provider: any WalkingRouteProvider, memo: RouteMemoStore, locationStore: any LocationAuthorizing) {
        self.provider = provider
        self.memo = memo
        self.locationStore = locationStore
    }

    /// Idempotent per `place.id`: a second call while `.resolving` is a
    /// no-op. First act is a memo lookup; last act on a terminal `.resolved`
    /// is a memo write (TRD §4.4, §4.7, §5).
    func resolve(for place: Place, hoods: [Hood], places: [Place]) async {
        if case .resolving = preview { return }

        if let memoized = memo.preview(for: place.id) {
            preview = memoized
            return
        }

        preview = .resolving

        guard locationStore.authorizationStatus == .authorizedWhenInUse
            || locationStore.authorizationStatus == .authorizedAlways
        else {
            preview = .noOrigin  // PRD req 6 — no polyline, no duration claimed, nothing memoised
            return
        }

        guard !Task.isCancelled else { return }

        let fastPlan: RoutePlan
        do {
            let fastLeg = try await provider.leg(
                from: .currentLocation,
                to: .coordinate(place.coordinate, name: place.name)
            )
            guard !fastLeg.coordinates.isEmpty else { throw RouteError.notFound }
            fastPlan = RoutePlan(
                kind: .fast, coordinates: fastLeg.coordinates, distance: fastLeg.distance,
                travelTime: fastLeg.travelTime, viaHoodName: nil
            )
        } catch {
            guard !Task.isCancelled else { return }
            preview = .failed  // nothing memoised — a transient failure is retried on next open
            return
        }

        guard !Task.isCancelled else { return }

        let scenic = await resolveScenic(fast: fastPlan, place: place, hoods: hoods, places: places)
        guard !Task.isCancelled else { return }

        let resolved = RoutePreview.resolved(fast: fastPlan, scenic: scenic)
        preview = resolved
        // Every terminal `.resolved` is memoised, success or stated-failure
        // alike — a `.noQualifyingHood` answer is as expensive to recompute
        // as a successful one and just as stable for 5 minutes (TRD §5).
        memo.store(resolved, for: place.id)
    }

    /// Pure local state; never triggers a request. PRD req 7's 400ms is met
    /// structurally, not by optimisation.
    func select(_ kind: RouteKind) {
        selection = kind
    }

    /// Clears this presentation's geometry only. Never touches the memo — a
    /// dismissal is not an invalidation.
    func reset() {
        preview = .idle
        selection = .fast
    }

    // MARK: - Scenic resolution (TRD §4.5, §4.6, §5)

    private func resolveScenic(
        fast: RoutePlan, place: Place, hoods: [Hood], places: [Place]
    ) async -> Result<RoutePlan, ScenicUnavailable> {
        guard let originCoordinate = fast.coordinates.first else {
            return .failure(.noQualifyingHood)
        }

        // Origin-and-destination-in-the-same-Hood (PRD req 4, bullet 2) is
        // checked before any candidate search (TRD §4.5).
        let originHoodID = HoodHitTester(hoods: hoods).hood(at: MKMapPoint(originCoordinate), tolerance: 0)?.id
        if originHoodID == place.hoodID {
            return .failure(.originAndDestinationShareAHood)
        }

        guard fast.travelTime >= RouteBounds.minimumFastTravelTime else {
            return .failure(.walkTooShort)
        }

        let candidates = ScenicWaypointPlanner.candidates(
            alongFastRoute: fast.coordinates, destinationHoodID: place.hoodID, hoods: hoods, places: places
        )
        guard !candidates.isEmpty else {
            return .failure(.noQualifyingHood)
        }

        let resolveStart = Date()
        var lastFailure: ScenicUnavailable = .detourTooLong

        for candidate in candidates.prefix(RouteBounds.maximumCandidateAttempts) {
            guard !Task.isCancelled else { return .failure(lastFailure) }
            guard Date().timeIntervalSince(resolveStart) < RouteBounds.resolveBudget else { break }

            switch await attempt(candidate: candidate, place: place, fast: fast) {
            case .success(let plan):
                return .success(plan)
            case .failure(let reason):
                lastFailure = reason
            }
        }

        return .failure(lastFailure)
    }

    /// One candidate's 2 concurrent legs (TRD §4.6): the fan-out A1 exists
    /// for — both endpoints cross the concurrency boundary as `RouteEndpoint`,
    /// a `Sendable` value type, where the non-`Sendable` MapKit item type
    /// the conformer builds internally cannot.
    private func attempt(
        candidate: WaypointCandidate, place: Place, fast: RoutePlan
    ) async -> Result<RoutePlan, ScenicUnavailable> {
        let waypoint = RouteEndpoint.coordinate(candidate.coordinate, name: candidate.hood.name)
        let destination = RouteEndpoint.coordinate(place.coordinate, name: place.name)

        do {
            async let toWaypoint = provider.leg(from: .currentLocation, to: waypoint)
            async let toDestination = provider.leg(from: waypoint, to: destination)
            let (first, second) = try await (toWaypoint, toDestination)

            let coordinates = RouteCorridor.concatenate(first.coordinates, second.coordinates)
            let totalDistance = first.distance + second.distance
            let totalTime = first.travelTime + second.travelTime

            guard RouteBounds.accepts(scenic: totalTime, fast: fast.travelTime) else {
                return .failure(.detourTooLong)
            }
            guard RouteCorridor.diverges(coordinates, from: fast.coordinates, minimumRun: 100, tolerance: 25) else {
                return .failure(.notDistinct)
            }

            let plan = RoutePlan(
                kind: .scenic, coordinates: coordinates, distance: totalDistance,
                travelTime: totalTime, viaHoodName: candidate.hood.name
            )
            return .success(plan)
        } catch {
            return .failure(.routingFailed)
        }
    }
}
