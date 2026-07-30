import MapKit
import Testing
@testable import Passenger

/// Covers the five cases the TRD names explicitly (§4.3), plus the 6th
/// `ios-code-reviewer` flagged at trd-review: a tap equidistant from two
/// adjacent, non-overlapping Hoods needs a stated, stable tie-break.
@Suite("HoodHitTester")
struct HoodHitTesterTests {
    private static func squareHood(id: String, originX: Double, originY: Double, side: Double = 100) -> Hood {
        let ring = [
            MKMapPoint(x: originX, y: originY),
            MKMapPoint(x: originX + side, y: originY),
            MKMapPoint(x: originX + side, y: originY + side),
            MKMapPoint(x: originX, y: originY + side),
        ]
        let rect = MKMapRect(x: originX, y: originY, width: side, height: side)
        let centroid = MKMapPoint(x: originX + side / 2, y: originY + side / 2).coordinate
        return Hood(id: id, name: id, ring: ring, boundingRect: rect, centroid: centroid)
    }

    /// An L-shaped concave ring whose bounding box includes the notch corner,
    /// which sits outside the polygon's actual area.
    private static func concaveHood() -> Hood {
        let ring = [
            MKMapPoint(x: 0, y: 0), MKMapPoint(x: 100, y: 0),
            MKMapPoint(x: 100, y: 40), MKMapPoint(x: 40, y: 40),
            MKMapPoint(x: 40, y: 100), MKMapPoint(x: 0, y: 100),
        ]
        let rect = MKMapRect(x: 0, y: 0, width: 100, height: 100)
        return Hood(id: "l-shape", name: "L", ring: ring, boundingRect: rect, centroid: MKMapPoint(x: 30, y: 30).coordinate)
    }

    @Test("a point inside the ring hits")
    func pointInside() {
        let tester = HoodHitTester(hoods: [Self.squareHood(id: "a", originX: 0, originY: 0)])
        #expect(tester.hood(at: MKMapPoint(x: 50, y: 50), tolerance: 5)?.id == "a")
    }

    @Test("a point far outside every ring and bbox misses")
    func pointOutside() {
        let tester = HoodHitTester(hoods: [Self.squareHood(id: "a", originX: 0, originY: 0)])
        #expect(tester.hood(at: MKMapPoint(x: 1000, y: 1000), tolerance: 5) == nil)
    }

    @Test("a point inside the bounding box but outside the ring misses (no tolerance)")
    func pointInBBoxOutsideRing() {
        let tester = HoodHitTester(hoods: [Self.concaveHood()])
        // (70, 70) sits in the bbox's notch corner, outside the L's actual area.
        #expect(tester.hood(at: MKMapPoint(x: 70, y: 70), tolerance: 0) == nil)
    }

    @Test("a concave notch is correctly excluded, and a point in the filled arm still hits")
    func concaveNotch() {
        let tester = HoodHitTester(hoods: [Self.concaveHood()])
        #expect(tester.hood(at: MKMapPoint(x: 90, y: 90), tolerance: 0) == nil)
        #expect(tester.hood(at: MKMapPoint(x: 20, y: 20), tolerance: 0)?.id == "l-shape")
    }

    @Test("a near-miss just outside the ring hits within tolerance, misses beyond it")
    func withinToleranceNearMiss() {
        let tester = HoodHitTester(hoods: [Self.squareHood(id: "a", originX: 0, originY: 0)])
        // (105, 50) is 5 map-points past the right edge.
        #expect(tester.hood(at: MKMapPoint(x: 105, y: 50), tolerance: 10)?.id == "a")
        #expect(tester.hood(at: MKMapPoint(x: 105, y: 50), tolerance: 2) == nil)
    }

    @Test("a tap equidistant from two adjacent Hoods resolves to the first by stable array order")
    func tieBreakAtSharedBoundary() {
        let left = Self.squareHood(id: "left", originX: 0, originY: 0)
        let right = Self.squareHood(id: "right", originX: 104, originY: 0)  // gap of 4 map-points
        let tester = HoodHitTester(hoods: [left, right])
        // x=102 is 2 map-points from both edges — equidistant, both within tolerance.
        #expect(tester.hood(at: MKMapPoint(x: 102, y: 50), tolerance: 5)?.id == "left")
    }
}
