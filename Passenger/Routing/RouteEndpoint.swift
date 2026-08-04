import CoreLocation

/// The only thing that crosses into `WalkingRouteProvider` (TRD §3.2, A1). A
/// value type, so the non-`Sendable` MapKit item type the conformer builds
/// internally never has to cross the `@MainActor` → provider hop, nor
/// `RoutePreviewModel`'s concurrent two-leg fan-out (TRD §4.6).
///
/// `.currentLocation` is symbolic: it names the device position without the
/// app ever holding it, which is TRD §3.3's privacy contract expressed in
/// the type system rather than in a comment. There is no case that carries a
/// `CLLocation`/fix of any kind — only a coordinate that is already public
/// (a place's own location) or the symbolic case.
enum RouteEndpoint: Sendable {
    case currentLocation
    case coordinate(CLLocationCoordinate2D, name: String?)
}

extension RouteEndpoint: Equatable {
    // Same reason as `RoutePlan`: `CLLocationCoordinate2D` isn't `Equatable`.
    static func == (lhs: RouteEndpoint, rhs: RouteEndpoint) -> Bool {
        switch (lhs, rhs) {
        case (.currentLocation, .currentLocation):
            return true
        case let (.coordinate(lCoordinate, lName), .coordinate(rCoordinate, rName)):
            return lCoordinate.latitude == rCoordinate.latitude
                && lCoordinate.longitude == rCoordinate.longitude
                && lName == rName
        default:
            return false
        }
    }
}
