import CoreLocation

/// Authorization status only — no coordinates, ever (TRD §3.3). This is a
/// privacy decision, not an accident: `Location/` never sees a `CLLocation`,
/// never calls `startUpdatingLocation`, and nothing here is persisted.
/// Recentering and the "you are here" marker are MapKit's own job
/// (`MapCameraPosition.userLocation`, `UserAnnotation()`) — this store exists
/// only to answer "what's the current authorization?" and "ask once."
@MainActor
@Observable
final class LocationStore: NSObject {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    /// No-op unless `.notDetermined` — a denied user is never re-prompted in
    /// the install (PRD req 6), and a double call can't double-prompt.
    func requestWhenInUseIfNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }
}

extension LocationStore: CLLocationManagerDelegate {
    // Not guaranteed to arrive on the main actor — hop explicitly rather than
    // assume the delegate callback thread.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
        }
    }
}
