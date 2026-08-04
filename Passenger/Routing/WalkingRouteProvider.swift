import CoreLocation
import MapKit

/// The only type in the app that touches `MKDirections` (TRD §2.2, §4.1).
protocol WalkingRouteProvider: Sendable {
    /// One leg. `MKDirections.Request` carries exactly one source and one
    /// destination — this signature is that limitation made explicit rather
    /// than hidden behind a waypoint parameter the API cannot honour.
    ///
    /// Takes `RouteEndpoint`, never `MKMapItem` (A1). `MKMapItem` is not
    /// `Sendable`, and this method is called from a `@MainActor` model and
    /// from `RoutePreviewModel`'s concurrent two-leg fan-out — under
    /// `SWIFT_STRICT_CONCURRENCY = complete` an `MKMapItem` parameter is a
    /// build failure or an `@unchecked Sendable`, and the second is banned
    /// (`passenger-code/CLAUDE.md`).
    func leg(from: RouteEndpoint, to: RouteEndpoint) async throws -> RouteLeg
}

/// One resolved leg, before concatenation (TRD §4.1).
struct RouteLeg: Sendable {
    let coordinates: [CLLocationCoordinate2D]
    let distance: CLLocationDistance
    let travelTime: TimeInterval
}

enum RouteError: Error, Equatable {
    case throttled
    case notFound
    case transport
}

/// The `MKDirections` conformer. Owns every MapKit type, start to finish,
/// inside this one function body — `MKMapItem`, `MKDirections`,
/// `MKDirections.Request` and `MKRoute` are constructed, used and discarded
/// here and never cross a concurrency boundary (TRD §2.2, §4.1, A1). What
/// crosses in is `RouteEndpoint`; what crosses out is `RouteLeg`. Both are
/// `Sendable` value types.
struct MapKitWalkingRouteProvider: WalkingRouteProvider {
    func leg(from origin: RouteEndpoint, to destination: RouteEndpoint) async throws -> RouteLeg {
        let request = MKDirections.Request()
        request.source = mapItem(for: origin)
        request.destination = mapItem(for: destination)
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let response: MKDirections.Response
        do {
            response = try await MKDirections(request: request).calculate()
        } catch let error as MKError {
            throw Self.mapError(error)
        }

        // Boundary validation, not defensive programming: an empty `routes`
        // array is `.notFound`, never a zero-length route (TRD §4.1).
        guard let route = response.routes.first else {
            throw RouteError.notFound
        }

        return RouteLeg(
            coordinates: Self.coordinates(of: route.polyline),
            distance: route.distance,
            travelTime: route.expectedTravelTime
        )
    }

    /// `.currentLocation` becomes `MKMapItem.forCurrentLocation()` here, in
    /// the same function that issues the request (TRD §3.3, §4.3) — MapKit
    /// resolves the device position internally; the app never asks
    /// CoreLocation for a coordinate and never receives a `CLLocation`.
    ///
    /// **Build-time contingency (TRD §4.3):** if `forCurrentLocation()` is
    /// unavailable on the iOS 26 SDK at build time, the fallback is a single
    /// `CLLocationManager.requestLocation()` confined to this function, its
    /// `CLLocation` used to build one `MKMapItem` and released here — never
    /// stored, never logged, never returned across the protocol. Not needed:
    /// `forCurrentLocation()` is live on the iOS 26 SDK this project builds
    /// against (confirmed at `trd-review`, TRD §4.3).
    private func mapItem(for endpoint: RouteEndpoint) -> MKMapItem {
        switch endpoint {
        case .currentLocation:
            return .forCurrentLocation()
        case let .coordinate(coordinate, name):
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let item = MKMapItem(location: location, address: nil)
            item.name = name
            return item
        }
    }

    private static func mapError(_ error: MKError) -> RouteError {
        switch error.code {
        case .loadingThrottled:
            return .throttled
        case .directionsNotFound, .placemarkNotFound:
            return .notFound
        default:
            return .transport
        }
    }

    /// `MKPolyline` carries its points through `getCoordinates(_:range:)`,
    /// not a settable array — this is the one place that unpacks it.
    private static func coordinates(of polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        return coordinates
    }
}
