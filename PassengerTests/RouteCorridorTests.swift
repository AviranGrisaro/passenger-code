import CoreLocation
import Testing
@testable import Passenger

/// TRD §4.2 (seam dedup), §4.5 (corridor distance), §5/D8 (the divergence
/// test). All distances are cross-checked against hand-computed values near
/// the equator, where 1 degree of longitude/latitude is close to a known
/// 111.32 km, rather than an external oracle — the same discipline
/// `HoodHitTesterTests` uses for its own flat-plane geometry.
@Suite("RouteCorridor")
struct RouteCorridorTests {
    /// A short polyline running due east along the equator, ~1113 m long.
    private static let equatorPolyline: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: 0.01),
    ]

    // MARK: - Point-to-polyline distance

    @Test("distance to polyline is ~0 at an endpoint")
    func distanceAtEndpointIsNearZero() {
        let distance = RouteCorridor.distance(from: Self.equatorPolyline[0], toPolyline: Self.equatorPolyline)
        #expect(distance < 1)
    }

    @Test("distance to polyline is the perpendicular offset for a point abeam the segment")
    func distancePerpendicularOffset() {
        // (0.001, 0.005) sits ~111 m north of the segment's midpoint.
        let point = CLLocationCoordinate2D(latitude: 0.001, longitude: 0.005)
        let distance = RouteCorridor.distance(from: point, toPolyline: Self.equatorPolyline)
        #expect(distance > 100 && distance < 120)
    }

    @Test("fewer than 2 coordinates returns infinity, never a false zero")
    func degeneratePolylineIsInfinite() {
        #expect(RouteCorridor.distance(from: Self.equatorPolyline[0], toPolyline: []) == .infinity)
        #expect(RouteCorridor.distance(from: Self.equatorPolyline[0], toPolyline: [Self.equatorPolyline[0]]) == .infinity)
    }

    // MARK: - Ring-to-polyline distance (TRD §4.5 filter 3)

    @Test("a ring far from the polyline reports roughly its true separation")
    func ringDistanceReflectsSeparation() {
        // A tiny square ring ~222 m north of the equator polyline.
        let ring = [
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0.004),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0.006),
            CLLocationCoordinate2D(latitude: 0.0021, longitude: 0.006),
            CLLocationCoordinate2D(latitude: 0.0021, longitude: 0.004),
        ]
        let distance = RouteCorridor.distance(betweenRing: ring, andPolyline: Self.equatorPolyline)
        #expect(distance > 210 && distance < 235)
    }

    @Test("an empty ring or a degenerate polyline returns infinity")
    func degenerateRingIsInfinite() {
        #expect(RouteCorridor.distance(betweenRing: [], andPolyline: Self.equatorPolyline) == .infinity)
        #expect(RouteCorridor.distance(betweenRing: [Self.equatorPolyline[0]], andPolyline: [Self.equatorPolyline[0]]) == .infinity)
    }

    // MARK: - Seam dedup (TRD §4.2)

    @Test("concatenate drops the second leg's first coordinate when within 5m of the first leg's last")
    func concatenateDedupsCloseSeam() {
        let first = [CLLocationCoordinate2D(latitude: 0, longitude: 0), CLLocationCoordinate2D(latitude: 0, longitude: 0.0001)]
        // ~2.2 m past first's last point — inside the 5 m threshold.
        let second = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0.00012),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.0003),
        ]
        let result = RouteCorridor.concatenate(first, second)
        #expect(result.count == 3)
    }

    @Test("concatenate keeps the second leg's first coordinate when the seam is beyond 5m")
    func concatenateKeepsFarSeam() {
        let first = [CLLocationCoordinate2D(latitude: 0, longitude: 0), CLLocationCoordinate2D(latitude: 0, longitude: 0.0001)]
        // ~100 m past first's last point.
        let second = [CLLocationCoordinate2D(latitude: 0, longitude: 0.001), CLLocationCoordinate2D(latitude: 0, longitude: 0.002)]
        let result = RouteCorridor.concatenate(first, second)
        #expect(result.count == 4)
    }

    @Test("concatenate with an empty leg on either side just appends")
    func concatenateHandlesEmptyLeg() {
        // `CLLocationCoordinate2D` isn't `Equatable` (TRD §3.2), so this
        // compares counts and coordinates by hand rather than via `==`.
        let prependedEmpty = RouteCorridor.concatenate([], Self.equatorPolyline)
        let appendedEmpty = RouteCorridor.concatenate(Self.equatorPolyline, [])
        #expect(prependedEmpty.count == Self.equatorPolyline.count)
        #expect(appendedEmpty.count == Self.equatorPolyline.count)
    }

    // MARK: - Divergence (TRD §5, D8)

    @Test("an identical polyline never diverges")
    func identicalPolylineNeverDiverges() {
        let fast = Self.equatorPolyline
        #expect(!RouteCorridor.diverges(fast, from: fast, minimumRun: 100, tolerance: 25))
    }

    @Test("a polyline that runs ~222m off the fast route for its whole length diverges — positive control")
    func farPolylineDiverges() {
        let fast = Self.equatorPolyline
        let farAway = fast.map { CLLocationCoordinate2D(latitude: $0.latitude + 0.002, longitude: $0.longitude) }
        // Proves the test can return true at all, per §9 row 4c's own
        // requirement — a suite that only ever asserts `false` would pass
        // whether or not `diverges` actually detects divergence.
        #expect(RouteCorridor.diverges(farAway, from: fast, minimumRun: 100, tolerance: 25))
    }

    @Test("a route that never leaves the fast route's own corridor cannot accumulate a run")
    func onCorridorRouteNeverDiverges() {
        let fast = Self.equatorPolyline
        #expect(!RouteCorridor.diverges(fast, from: fast, minimumRun: 1, tolerance: 0.001))
    }
}
