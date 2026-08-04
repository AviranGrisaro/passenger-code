import CoreLocation
import MapKit
import SwiftUI

/// A route hand-off target — name plus destination coordinate (TRD §4.6).
struct RouteDestination: Sendable {
    let name: String
    let coordinate: CLLocationCoordinate2D
}

/// V1 builds Apple Maps only (TRD §8 D3) — Waze's deep-link scheme exposes
/// no walking parameter, and a PRD requirement (walking mode, req 5) is not
/// the architect's to trade away. `RouteApp` is an enum precisely so a future
/// case is a compile-checked addition, not a rewrite.
enum RouteApp: String, Sendable, CaseIterable {
    case appleMaps
}

/// Route hand-off, walking mode, availability (TRD §4.6). Walking mode is
/// set in exactly one place here, so no branch can drop it.
struct DirectionsService: Sendable {
    /// Apps installed on this device that can honour a walking destination.
    ///
    /// Always `[.appleMaps]` in V1 — Apple Maps is a system app that cannot
    /// be uninstalled, so no `canOpenURL` probe is needed and
    /// `LSApplicationQueriesSchemes` gains no entry for it (TRD §8 D3). The
    /// disabled branch this can drive (`availableApps().isEmpty`) is still
    /// built in `PlaceDetailModal` — unreachable in production, but the PRD
    /// requires the empty case be handled, not assumed impossible.
    func availableApps() -> [RouteApp] {
        [.appleMaps]
    }

    func open(_ app: RouteApp, to destination: RouteDestination) {
        switch app {
        case .appleMaps:
            // iOS 26 API: `MKMapItem(location:address:)` replaces the
            // `MKPlacemark`-based initializer, deprecated this release.
            let location = CLLocation(latitude: destination.coordinate.latitude, longitude: destination.coordinate.longitude)
            let mapItem = MKMapItem(location: location, address: nil)
            mapItem.name = destination.name
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        }
    }
}

/// scenic-walk TRD §4.8: Apple Maps takes a destination, not an itinerary.
/// There is no public API that carries an intermediate stop into it, so a
/// scenic selection is always disclosed before the user leaves (PRD req 5).
/// The hand-off itself gains no new parameter — `open(_:to:)` above is
/// unchanged, walking mode only, exactly as T-033 built it.
extension DirectionsService {
    static let waypointDisclosure = "Maps gets the destination only — the scenic detour stays here."
}

/// `PlaceDetailModal(place:)` reads this from the environment (TRD §4.8). A
/// plain `Sendable` struct with no observable state doesn't fit the
/// `@Observable`/`@Environment(Type.self)` idiom `PlaceCatalog`/`DetailRouter`/
/// `SavedPlacesStore` use — a classic `EnvironmentKey` is the correct seam
/// for a stateless service dependency like this one.
private struct DirectionsServiceKey: EnvironmentKey {
    static let defaultValue = DirectionsService()
}

extension EnvironmentValues {
    var directionsService: DirectionsService {
        get { self[DirectionsServiceKey.self] }
        set { self[DirectionsServiceKey.self] = newValue }
    }
}
