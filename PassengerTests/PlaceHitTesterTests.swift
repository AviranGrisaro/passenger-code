import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers TRD §4.5's nearest-within-tolerance contract, plus the tie-break
/// `HoodHitTesterTests` established a precedent for.
///
/// Every point here is built as a small offset from `anchor`, a real
/// Tel-Aviv-ish coordinate, rather than from `MKMapPoint(x:0,y:0)` directly.
/// `HoodHitTesterTests` can use raw, near-zero `MKMapPoint`s safely because
/// `Hood.ring` is *stored* in `MKMapPoint`s and never round-trips through a
/// coordinate. `Place.coordinate` is a `CLLocationCoordinate2D` (TRD §3.2),
/// so every test place here is built via `MKMapPoint(...).coordinate` and
/// `PlaceHitTester` converts it straight back to `MKMapPoint` — a round trip
/// that is only precise at a normal latitude. Near-zero map points sit at
/// the Mercator projection's extreme corner (~85°N), where that round trip
/// loses many orders of magnitude more precision than these single-digit
/// map-point tolerances can tolerate.
@Suite("PlaceHitTester")
struct PlaceHitTesterTests {
    private static let anchor = MKMapPoint(CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77))

    private static func place(id: String, dx: Double, dy: Double) -> Place {
        Place(
            id: id,
            name: id,
            category: .eatDrink,
            hoodID: "florentin",
            coordinate: MKMapPoint(x: anchor.x + dx, y: anchor.y + dy).coordinate
        )
    }

    private static func point(dx: Double, dy: Double) -> MKMapPoint {
        MKMapPoint(x: anchor.x + dx, y: anchor.y + dy)
    }

    @Test("a point exactly on a place's coordinate hits")
    func exactHit() {
        let tester = PlaceHitTester(places: [Self.place(id: "a", dx: 50, dy: 50)])
        #expect(tester.place(at: Self.point(dx: 50, dy: 50), tolerance: 5)?.id == "a")
    }

    @Test("a point far outside every place's tolerance misses")
    func miss() {
        let tester = PlaceHitTester(places: [Self.place(id: "a", dx: 50, dy: 50)])
        #expect(tester.place(at: Self.point(dx: 1000, dy: 1000), tolerance: 5) == nil)
    }

    @Test("a near-miss just outside tolerance misses, just inside it hits")
    func withinToleranceNearMiss() {
        // `MKMapPoint.distance(to:)` returns geographic distance (meters,
        // scaled by `MKMetersPerMapPointAtLatitude`), not a raw Euclidean
        // count of map-point units — at this anchor's latitude the scale
        // factor is ~0.126, so an 8-map-point offset is only ~1.0 in the
        // unit `tolerance` is measured in. dx=40 gives ~5.0, a comfortable
        // margin inside `tolerance: 10` and outside `tolerance: 2` without
        // depending on a razor-thin float boundary.
        let tester = PlaceHitTester(places: [Self.place(id: "a", dx: 0, dy: 0)])
        #expect(tester.place(at: Self.point(dx: 40, dy: 0), tolerance: 10)?.id == "a")
        #expect(tester.place(at: Self.point(dx: 40, dy: 0), tolerance: 2) == nil)
    }

    @Test("the nearer of two in-tolerance places wins")
    func nearerPlaceWins() {
        let near = Self.place(id: "near", dx: 10, dy: 0)
        let far = Self.place(id: "far", dx: 20, dy: 0)
        let tester = PlaceHitTester(places: [far, near])
        #expect(tester.place(at: Self.point(dx: 9, dy: 0), tolerance: 15)?.id == "near")
    }

    @Test("a tap equidistant from two places resolves to the first by stable array order")
    func tieBreakIsStableArrayOrder() {
        let left = Self.place(id: "left", dx: 0, dy: 0)
        let right = Self.place(id: "right", dx: 20, dy: 0)
        let tester = PlaceHitTester(places: [left, right])
        // dx=10 is 10 map-points from both — equidistant, both within tolerance.
        #expect(tester.place(at: Self.point(dx: 10, dy: 0), tolerance: 15)?.id == "left")
    }

    @Test("an empty catalog never hits")
    func emptyCatalogMisses() {
        let tester = PlaceHitTester(places: [])
        #expect(tester.place(at: Self.point(dx: 0, dy: 0), tolerance: 1000) == nil)
    }
}
