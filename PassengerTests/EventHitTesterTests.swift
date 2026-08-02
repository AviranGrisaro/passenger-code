import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers TRD §4.5/D7's nearest-within-tolerance contract — mirrors
/// `PlaceHitTesterTests` exactly, including its reasoning for building every
/// point as an offset from a real Tel-Aviv-ish anchor rather than
/// `MKMapPoint(x:0,y:0)` directly (Mercator precision near the origin).
@Suite("EventHitTester")
struct EventHitTesterTests {
    private static let anchor = MKMapPoint(CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77))

    private static func event(id: String, dx: Double, dy: Double) -> LiveEvent {
        LiveEvent(
            id: id, name: id,
            startAt: Date(), endAt: Date().addingTimeInterval(3600),
            coordinate: MKMapPoint(x: anchor.x + dx, y: anchor.y + dy).coordinate,
            venueName: nil, hoodID: "florentin", category: nil, rank: 0.5, sourceName: nil
        )
    }

    private static func point(dx: Double, dy: Double) -> MKMapPoint {
        MKMapPoint(x: anchor.x + dx, y: anchor.y + dy)
    }

    @Test("a point exactly on an event's coordinate hits")
    func exactHit() {
        let tester = EventHitTester(events: [Self.event(id: "a", dx: 50, dy: 50)])
        #expect(tester.event(at: Self.point(dx: 50, dy: 50), tolerance: 5)?.id == "a")
    }

    @Test("a point far outside every event's tolerance misses")
    func miss() {
        let tester = EventHitTester(events: [Self.event(id: "a", dx: 50, dy: 50)])
        #expect(tester.event(at: Self.point(dx: 1000, dy: 1000), tolerance: 5) == nil)
    }

    @Test("a near-miss just outside tolerance misses, just inside it hits")
    func withinToleranceNearMiss() {
        // Same scale-factor reasoning as `PlaceHitTesterTests`: at this
        // anchor's latitude, dx=40 map-points is ~5.0 in the unit
        // `tolerance` is measured in.
        let tester = EventHitTester(events: [Self.event(id: "a", dx: 0, dy: 0)])
        #expect(tester.event(at: Self.point(dx: 40, dy: 0), tolerance: 10)?.id == "a")
        #expect(tester.event(at: Self.point(dx: 40, dy: 0), tolerance: 2) == nil)
    }

    @Test("the nearer of two in-tolerance events wins")
    func nearerEventWins() {
        let near = Self.event(id: "near", dx: 10, dy: 0)
        let far = Self.event(id: "far", dx: 20, dy: 0)
        let tester = EventHitTester(events: [far, near])
        #expect(tester.event(at: Self.point(dx: 9, dy: 0), tolerance: 15)?.id == "near")
    }

    @Test("a tap equidistant from two events resolves to the first by stable array order")
    func tieBreakIsStableArrayOrder() {
        let left = Self.event(id: "left", dx: 0, dy: 0)
        let right = Self.event(id: "right", dx: 20, dy: 0)
        let tester = EventHitTester(events: [left, right])
        #expect(tester.event(at: Self.point(dx: 10, dy: 0), tolerance: 15)?.id == "left")
    }

    @Test("an empty event set never hits")
    func emptySetMisses() {
        let tester = EventHitTester(events: [])
        #expect(tester.event(at: Self.point(dx: 0, dy: 0), tolerance: 1000) == nil)
    }
}
