import CoreLocation
import Testing
@testable import Passenger

/// `open(_:to:)` hands off to `UIApplication`/MapKit's own app-switch and
/// isn't meaningfully unit-testable; this covers what is (TRD §4.6, §8 D3).
@Suite("DirectionsService")
struct DirectionsServiceTests {
    @Test("availableApps() is always [.appleMaps] in V1 — no Waze, no canOpenURL probe")
    func availableAppsIsAppleMapsOnly() {
        let service = DirectionsService()
        #expect(service.availableApps() == [.appleMaps])
    }

    @Test("availableApps() is never empty in V1 — the disabled branch it can drive is unreachable in production")
    func availableAppsIsNeverEmpty() {
        let service = DirectionsService()
        #expect(!service.availableApps().isEmpty)
    }
}
