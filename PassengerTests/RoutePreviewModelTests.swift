import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// TRD §9 rows 3, 4, 6, 7, 10 — the resolve loop, the request-volume caps,
/// and the memo hand-off, all against a scripted `WalkingRouteProvider` so
/// nothing here issues a real `MKDirections` request (TRD §8 R5).
@Suite("RoutePreviewModel")
@MainActor
struct RoutePreviewModelTests {
    private struct FixedAuthorization: LocationAuthorizing {
        let authorizationStatus: CLAuthorizationStatus
    }

    /// Records every call and dispatches by pattern-matching the endpoints
    /// (TRD §4.1's own note: "a scripted `WalkingRouteProvider` now scripts
    /// on `RouteEndpoint`, a value type it can pattern-match") rather than
    /// by call order — the two legs of one attempt run concurrently
    /// (§4.6), so their arrival order at this actor isn't guaranteed.
    private actor ScriptedProvider: WalkingRouteProvider {
        private(set) var callCount = 0
        private let destinationName: String
        private let fastLeg: RouteLeg
        private let toWaypointLeg: RouteLeg
        private let toDestinationLeg: RouteLeg
        private let failWaypointLegs: Bool

        init(destinationName: String, fastLeg: RouteLeg, toWaypointLeg: RouteLeg, toDestinationLeg: RouteLeg, failWaypointLegs: Bool = false) {
            self.destinationName = destinationName
            self.fastLeg = fastLeg
            self.toWaypointLeg = toWaypointLeg
            self.toDestinationLeg = toDestinationLeg
            self.failWaypointLegs = failWaypointLegs
        }

        func leg(from: RouteEndpoint, to: RouteEndpoint) async throws -> RouteLeg {
            callCount += 1
            switch (from, to) {
            case (.currentLocation, .coordinate(_, let name)) where name == destinationName:
                return fastLeg
            case (.currentLocation, .coordinate):
                if failWaypointLegs { throw RouteError.transport }
                return toWaypointLeg
            case (.coordinate, .coordinate(_, let name)) where name == destinationName:
                if failWaypointLegs { throw RouteError.transport }
                return toDestinationLeg
            default:
                throw RouteError.notFound
            }
        }
    }

    private actor FailingProvider: WalkingRouteProvider {
        private(set) var callCount = 0
        func leg(from: RouteEndpoint, to: RouteEndpoint) async throws -> RouteLeg {
            callCount += 1
            throw RouteError.notFound
        }
    }

    // MARK: - Fixtures

    private static let originCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    private static let destinationCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0.02)  // ~2226m east

    private static func makePlace(hoodID: String = "destination-hood") -> Place {
        Place(
            id: "cafe", name: "Cafe", category: .eatDrink, hoodID: hoodID,
            coordinate: destinationCoordinate, permanentlyClosed: false, placeType: "cafe"
        )
    }

    /// A fast leg long enough (> `RouteBounds.minimumFastTravelTime`) to
    /// clear the `.walkTooShort` gate, unless a test deliberately shortens it.
    private static func fastLeg(travelTime: TimeInterval = 1200) -> RouteLeg {
        RouteLeg(coordinates: [originCoordinate, destinationCoordinate], distance: 1600, travelTime: travelTime)
    }

    /// Two candidate Hoods, both `false`-flagged, both within the corridor
    /// and off-route bands, and neither the origin's nor destination's Hood
    /// — enough for a "first candidate accepted"/"both candidates rejected"
    /// pair of tests without needing precise ranking.
    private static func candidateHoods() -> [Hood] {
        [squareHood(id: "scenic-a", metersNorth: 400), squareHood(id: "scenic-b", metersNorth: 500)]
    }

    private static func squareHood(id: String, metersNorth: Double) -> Hood {
        let metersPerDegree = 111_320.0
        let center = CLLocationCoordinate2D(latitude: metersNorth / metersPerDegree, longitude: 0.01)
        return hood(id: id, center: center)
    }

    /// A small square Hood centred exactly on `center` — used both for the
    /// corridor candidates above and, with `center` set to the route's own
    /// origin, for the "origin and destination share a Hood" fixture below.
    private static func hood(id: String, center: CLLocationCoordinate2D) -> Hood {
        let metersPerDegree = 111_320.0
        let half = 10.0 / metersPerDegree
        let ring = [
            CLLocationCoordinate2D(latitude: center.latitude - half, longitude: center.longitude - half),
            CLLocationCoordinate2D(latitude: center.latitude - half, longitude: center.longitude + half),
            CLLocationCoordinate2D(latitude: center.latitude + half, longitude: center.longitude + half),
            CLLocationCoordinate2D(latitude: center.latitude + half, longitude: center.longitude - half),
        ].map(MKMapPoint.init)
        let xs = ring.map(\.x)
        let ys = ring.map(\.y)
        let rect = MKMapRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        return Hood(id: id, name: id, ring: ring, boundingRect: rect, centroid: center, blurb: nil, isTouristTrap: false, designatedForProgression: false)
    }

    // MARK: - Authorization gate (§9 row 6)

    @Test("authorization denied resolves to .noOrigin and issues zero requests")
    func deniedAuthorizationIsNoOrigin() async {
        let provider = FailingProvider()
        let model = RoutePreviewModel(
            provider: provider, memo: RouteMemoStore(), locationStore: FixedAuthorization(authorizationStatus: .denied)
        )
        await model.resolve(for: Self.makePlace(), hoods: [], places: [])
        #expect(model.preview == .noOrigin)
        #expect(await provider.callCount == 0)
    }

    @Test("authorization restricted also resolves to .noOrigin")
    func restrictedAuthorizationIsNoOrigin() async {
        let provider = FailingProvider()
        let model = RoutePreviewModel(
            provider: provider, memo: RouteMemoStore(), locationStore: FixedAuthorization(authorizationStatus: .restricted)
        )
        await model.resolve(for: Self.makePlace(), hoods: [], places: [])
        #expect(model.preview == .noOrigin)
        #expect(await provider.callCount == 0)
    }

    // MARK: - Fast leg failure

    @Test("a fast-leg failure resolves to .failed, not memoised")
    func fastLegFailureResolvesToFailed() async {
        let provider = FailingProvider()
        let memo = RouteMemoStore()
        let model = RoutePreviewModel(
            provider: provider, memo: memo, locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse)
        )
        await model.resolve(for: Self.makePlace(), hoods: [], places: [])
        #expect(model.preview == .failed)
        #expect(memo.preview(for: "cafe") == nil)
    }

    // MARK: - Stated scenic-unavailable states (§9 row 4)

    @Test("origin and destination sharing a Hood resolves .originAndDestinationShareAHood with a single request")
    func sameHoodResolvesToStatedState() async {
        // Centred exactly on the route's own origin coordinate, so
        // `HoodHitTester` actually contains it — a hood merely *named*
        // "destination-hood" without geometry over the origin would never
        // trigger this branch.
        let sharedHood = Self.hood(id: "destination-hood", center: Self.originCoordinate)
        let provider = ScriptedProvider(
            destinationName: "Cafe", fastLeg: Self.fastLeg(), toWaypointLeg: Self.fastLeg(), toDestinationLeg: Self.fastLeg()
        )
        let model = RoutePreviewModel(
            provider: provider, memo: RouteMemoStore(), locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse)
        )
        await model.resolve(for: Self.makePlace(hoodID: "destination-hood"), hoods: [sharedHood], places: [])

        guard case .resolved(_, let scenic) = model.preview, case .failure(.originAndDestinationShareAHood) = scenic else {
            Issue.record("expected .originAndDestinationShareAHood, got \(model.preview)")
            return
        }
        #expect(await provider.callCount == 1)
    }

    @Test("a fast route under the minimum travel time resolves .walkTooShort")
    func shortWalkResolvesToWalkTooShort() async {
        let provider = ScriptedProvider(
            destinationName: "Cafe", fastLeg: Self.fastLeg(travelTime: 200), toWaypointLeg: Self.fastLeg(), toDestinationLeg: Self.fastLeg()
        )
        let model = RoutePreviewModel(
            provider: provider, memo: RouteMemoStore(), locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse)
        )
        await model.resolve(for: Self.makePlace(), hoods: Self.candidateHoods(), places: [])

        guard case .resolved(_, let scenic) = model.preview, case .failure(.walkTooShort) = scenic else {
            Issue.record("expected .walkTooShort, got \(model.preview)")
            return
        }
        #expect(await provider.callCount == 1)
    }

    @Test("no qualifying Hood in the corridor resolves .noQualifyingHood")
    func noCandidatesResolvesToNoQualifyingHood() async {
        let provider = ScriptedProvider(
            destinationName: "Cafe", fastLeg: Self.fastLeg(), toWaypointLeg: Self.fastLeg(), toDestinationLeg: Self.fastLeg()
        )
        let model = RoutePreviewModel(
            provider: provider, memo: RouteMemoStore(), locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse)
        )
        // No hoods at all — the candidate search is structurally empty.
        await model.resolve(for: Self.makePlace(), hoods: [], places: [])

        guard case .resolved(_, let scenic) = model.preview, case .failure(.noQualifyingHood) = scenic else {
            Issue.record("expected .noQualifyingHood, got \(model.preview)")
            return
        }
        #expect(await provider.callCount == 1)
    }

    // MARK: - Accepted scenic route + request volume (§9 row 10)

    @Test("an accepted first candidate resolves .success and issues exactly 3 requests")
    func acceptedCandidateIssuesExactlyThreeRequests() async {
        // Diverges clearly from the fast route (well beyond 25m tolerance)
        // and stays inside the detour bound (fast=1200s -> accepts <= 1800s).
        let scenicNorth = CLLocationCoordinate2D(latitude: 0.01, longitude: 0.01)
        let toWaypoint = RouteLeg(coordinates: [Self.originCoordinate, scenicNorth], distance: 600, travelTime: 500)
        let toDestination = RouteLeg(coordinates: [scenicNorth, Self.destinationCoordinate], distance: 600, travelTime: 500)
        let provider = ScriptedProvider(
            destinationName: "Cafe", fastLeg: Self.fastLeg(), toWaypointLeg: toWaypoint, toDestinationLeg: toDestination
        )
        let memo = RouteMemoStore()
        let model = RoutePreviewModel(provider: provider, memo: memo, locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse))

        await model.resolve(for: Self.makePlace(), hoods: Self.candidateHoods(), places: [])

        guard case .resolved(_, let scenic) = model.preview, case .success(let plan) = scenic else {
            Issue.record("expected a successful scenic plan, got \(model.preview)")
            return
        }
        #expect(plan.viaHoodName != nil)
        #expect(await provider.callCount == 3)
        #expect(memo.preview(for: "cafe") != nil)  // terminal .resolved is memoised
    }

    @Test("both candidates rejected on divergence resolves .notDistinct and issues exactly 5 requests")
    func bothCandidatesRejectedIssuesExactlyFiveRequests() async {
        // Identical to the fast route's own coordinates — never diverges.
        let toWaypoint = RouteLeg(coordinates: [Self.originCoordinate, Self.destinationCoordinate], distance: 1600, travelTime: 600)
        let toDestination = RouteLeg(coordinates: [Self.destinationCoordinate], distance: 0, travelTime: 0)
        let provider = ScriptedProvider(
            destinationName: "Cafe", fastLeg: Self.fastLeg(), toWaypointLeg: toWaypoint, toDestinationLeg: toDestination
        )
        let model = RoutePreviewModel(
            provider: provider, memo: RouteMemoStore(), locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse)
        )

        await model.resolve(for: Self.makePlace(), hoods: Self.candidateHoods(), places: [])

        guard case .resolved(_, let scenic) = model.preview, case .failure(.notDistinct) = scenic else {
            Issue.record("expected .notDistinct after both candidates rejected, got \(model.preview)")
            return
        }
        #expect(await provider.callCount == 5)
    }

    @Test("a scenic leg failure produces .routingFailed, and the fast route is still offered")
    func scenicLegFailureProducesRoutingFailed() async {
        let provider = ScriptedProvider(
            destinationName: "Cafe", fastLeg: Self.fastLeg(), toWaypointLeg: Self.fastLeg(), toDestinationLeg: Self.fastLeg(),
            failWaypointLegs: true
        )
        let model = RoutePreviewModel(
            provider: provider, memo: RouteMemoStore(), locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse)
        )

        await model.resolve(for: Self.makePlace(), hoods: [Self.squareHood(id: "scenic-a", metersNorth: 400)], places: [])

        guard case .resolved(let fast, let scenic) = model.preview, case .failure(.routingFailed) = scenic else {
            Issue.record("expected .routingFailed, got \(model.preview)")
            return
        }
        #expect(!fast.coordinates.isEmpty)  // the fast route is still offered
    }

    // MARK: - select() is free (§9 row 7a)

    @Test("select() never calls the provider — a route-control tap is pure local state")
    func selectNeverCallsProvider() async {
        let provider = FailingProvider()
        let model = RoutePreviewModel(
            provider: provider, memo: RouteMemoStore(), locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse)
        )
        for _ in 0..<5 {
            model.select(.scenic)
            model.select(.fast)
        }
        #expect(model.selection == .fast)
        #expect(await provider.callCount == 0)
    }

    // MARK: - Memo hand-off (§9 row 10 — re-open within/after TTL)

    @Test("re-opening the same place within the memo's TTL issues zero further requests")
    func reopenWithinTTLIssuesNoFurtherRequests() async {
        let provider = ScriptedProvider(
            destinationName: "Cafe", fastLeg: Self.fastLeg(travelTime: 200), toWaypointLeg: Self.fastLeg(), toDestinationLeg: Self.fastLeg()
        )
        let memo = RouteMemoStore()
        let firstModel = RoutePreviewModel(provider: provider, memo: memo, locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse))
        await firstModel.resolve(for: Self.makePlace(), hoods: [], places: [])
        let firstResult = firstModel.preview
        let countAfterFirst = await provider.callCount

        // A second, independent model for the same place-modal
        // presentation lifecycle (TRD §4.4: torn down and recreated), same
        // shared memo store (A2).
        let secondModel = RoutePreviewModel(provider: provider, memo: memo, locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse))
        await secondModel.resolve(for: Self.makePlace(), hoods: [], places: [])

        #expect(secondModel.preview == firstResult)
        #expect(await provider.callCount == countAfterFirst)  // +0
    }

    @Test("reset() clears this presentation's state but never touches the memo")
    func resetClearsStateNotMemo() async {
        let provider = ScriptedProvider(
            destinationName: "Cafe", fastLeg: Self.fastLeg(travelTime: 200), toWaypointLeg: Self.fastLeg(), toDestinationLeg: Self.fastLeg()
        )
        let memo = RouteMemoStore()
        let model = RoutePreviewModel(provider: provider, memo: memo, locationStore: FixedAuthorization(authorizationStatus: .authorizedWhenInUse))
        await model.resolve(for: Self.makePlace(), hoods: [], places: [])
        model.select(.scenic)

        model.reset()

        #expect(model.preview == .idle)
        #expect(model.selection == .fast)
        #expect(memo.preview(for: "cafe") != nil)  // the memo survives the reset
    }
}
