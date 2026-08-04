import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// TRD §9 rows 2 and 9. Fixtures are built near the equator (latitude 0),
/// same reasoning as `RouteCorridorTests`: 1 degree of latitude/longitude is
/// close to a known 111.32 km there, so expected distances are hand
/// computable rather than needing an external oracle.
@Suite("ScenicWaypointPlanner")
struct ScenicWaypointPlannerTests {
    private static let metersPerDegree = 111_320.0

    private static func degrees(forMeters meters: Double) -> Double { meters / metersPerDegree }

    /// A small square Hood centred on `center`, far smaller than any
    /// distance under test, so ring distance and centroid distance are
    /// effectively the same value.
    private static func squareHood(
        id: String, center: CLLocationCoordinate2D, isTouristTrap: Bool?
    ) -> Hood {
        let half = degrees(forMeters: 10)
        let corners = [
            CLLocationCoordinate2D(latitude: center.latitude - half, longitude: center.longitude - half),
            CLLocationCoordinate2D(latitude: center.latitude - half, longitude: center.longitude + half),
            CLLocationCoordinate2D(latitude: center.latitude + half, longitude: center.longitude + half),
            CLLocationCoordinate2D(latitude: center.latitude + half, longitude: center.longitude - half),
        ]
        let ring = corners.map(MKMapPoint.init)
        let xs = ring.map(\.x)
        let ys = ring.map(\.y)
        let rect = MKMapRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        return Hood(id: id, name: id, ring: ring, boundingRect: rect, centroid: center, blurb: nil, isTouristTrap: isTouristTrap, designatedForProgression: false)
    }

    private static func makePlace(id: String, hoodID: String, coordinate: CLLocationCoordinate2D) -> Place {
        Place(id: id, name: id, category: .eatDrink, hoodID: hoodID, coordinate: coordinate, permanentlyClosed: false, placeType: "cafe")
    }

    /// A straight polyline running east along the equator, ~2226 m long —
    /// the "fast route" for most of these tests.
    private static let straightRoute: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: degrees(forMeters: 2226)),
    ]

    /// North of the route's midpoint by `metersNorth`.
    private static func pointNearRoute(metersNorth: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: degrees(forMeters: metersNorth), longitude: degrees(forMeters: 1113))
    }

    // MARK: - Row 2: null is never a waypoint

    @Test("only false-flagged hoods are ever candidates — null and true are excluded")
    func onlyFalseFlaggedHoodsAreCandidates() {
        let inCorridor = Self.pointNearRoute(metersNorth: 500)
        let hoods = (0..<3).map { Self.squareHood(id: "null-\($0)", center: inCorridor, isTouristTrap: nil) }
            + (0..<2).map { Self.squareHood(id: "true-\($0)", center: inCorridor, isTouristTrap: true) }
            + (0..<3).map { Self.squareHood(id: "false-\($0)", center: inCorridor, isTouristTrap: false) }

        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute, destinationHoodID: "destination", hoods: hoods, places: []
        )

        #expect(result.count == 3)
        #expect(result.allSatisfy { $0.hood.isTouristTrap == false })
    }

    @Test("an all-null hood set produces no candidates")
    func allNullProducesNoCandidates() {
        let inCorridor = Self.pointNearRoute(metersNorth: 500)
        let hoods = (0..<8).map { Self.squareHood(id: "null-\($0)", center: inCorridor, isTouristTrap: nil) }
        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute, destinationHoodID: "destination", hoods: hoods, places: []
        )
        #expect(result.isEmpty)
    }

    @Test("false-flagged hoods entirely outside the corridor still produce no candidates — the corridor filter is independent of the flag filter")
    func falseFlaggedButOutOfCorridorProducesNoCandidates() {
        let farAway = Self.pointNearRoute(metersNorth: 5000)
        let hoods = (0..<3).map { Self.squareHood(id: "false-\($0)", center: farAway, isTouristTrap: false) }
        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute, destinationHoodID: "destination", hoods: hoods, places: []
        )
        #expect(result.isEmpty)
    }

    @Test("the destination's own hood is never a candidate")
    func destinationHoodExcluded() {
        let hood = Self.squareHood(id: "destination", center: Self.pointNearRoute(metersNorth: 500), isTouristTrap: false)
        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute, destinationHoodID: "destination", hoods: [hood], places: []
        )
        #expect(result.isEmpty)
    }

    @Test("the hood containing the route's own origin is never a candidate")
    func originHoodExcluded() {
        // Centred exactly on the route's first coordinate.
        let originHood = Self.squareHood(id: "origin", center: Self.straightRoute[0], isTouristTrap: false)
        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute, destinationHoodID: "destination", hoods: [originHood], places: []
        )
        #expect(result.isEmpty)
    }

    // MARK: - Row 9: the corridor follows the fast route, not the straight chord

    @Test("a bend in the fast route is what the corridor follows, not the A->B chord")
    func corridorFollowsRouteNotChord() {
        // An L-shaped route: east, then sharply north. The straight chord
        // from start to end runs diagonally, far from either leg.
        let bentRoute = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: Self.degrees(forMeters: 2000)),
            CLLocationCoordinate2D(latitude: Self.degrees(forMeters: 2000), longitude: Self.degrees(forMeters: 2000)),
        ]
        // The straight A->B chord's own midpoint: ~1000m from *both* actual
        // legs of the L-shaped route (leg 1 is due east at latitude 0, leg 2
        // is due north at longitude 2000m) — on the chord, but well outside
        // the 800m corridor around the route that actually gets walked.
        let nearChordFarFromRoute = Self.squareHood(
            id: "near-chord",
            center: CLLocationCoordinate2D(latitude: Self.degrees(forMeters: 1000), longitude: Self.degrees(forMeters: 1000)),
            isTouristTrap: false
        )
        // ~400m off the route's second (northward) leg — inside the corridor.
        let nearRoute = Self.squareHood(
            id: "near-route",
            center: CLLocationCoordinate2D(latitude: Self.degrees(forMeters: 1000), longitude: Self.degrees(forMeters: 2000 + 400)),
            isTouristTrap: false
        )

        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: bentRoute, destinationHoodID: "destination", hoods: [nearChordFarFromRoute, nearRoute], places: []
        )

        #expect(!result.contains { $0.hood.id == "near-chord" })
        #expect(result.contains { $0.hood.id == "near-route" })
    }

    @Test("a hood under minimumOffRoute (250m) is excluded, and one over maximumOffRoute (1200m) is excluded, with a passing control at 500m")
    func offRouteBandBounds() {
        let tooClose = Self.squareHood(id: "too-close", center: Self.pointNearRoute(metersNorth: 100), isTouristTrap: false)
        let tooFar = Self.squareHood(id: "too-far", center: Self.pointNearRoute(metersNorth: 1500), isTouristTrap: false)
        let control = Self.squareHood(id: "control", center: Self.pointNearRoute(metersNorth: 500), isTouristTrap: false)

        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute, destinationHoodID: "destination", hoods: [tooClose, tooFar, control], places: []
        )

        #expect(!result.contains { $0.hood.id == "too-close" })
        #expect(!result.contains { $0.hood.id == "too-far" })
        #expect(result.contains { $0.hood.id == "control" })
    }

    // MARK: - Waypoint selection and ranking (TRD §4.5b/c)

    @Test("the waypoint is the hood's curated place nearest the fast route when one exists")
    func waypointPrefersNearestCuratedPlace() throws {
        let center = Self.pointNearRoute(metersNorth: 500)
        let hood = Self.squareHood(id: "florentin", center: center, isTouristTrap: false)
        let farPlace = Self.makePlace(id: "far-place", hoodID: "florentin", coordinate: Self.pointNearRoute(metersNorth: 900))
        let nearPlace = Self.makePlace(id: "near-place", hoodID: "florentin", coordinate: Self.pointNearRoute(metersNorth: 260))

        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute, destinationHoodID: "destination", hoods: [hood], places: [farPlace, nearPlace]
        )

        let candidate = try #require(result.first)
        #expect(candidate.coordinate.latitude == nearPlace.coordinate.latitude)
        #expect(candidate.curatedPlaceCount == 2)
    }

    @Test("the waypoint falls back to the hood's centroid when it has no curated place")
    func waypointFallsBackToCentroid() throws {
        let center = Self.pointNearRoute(metersNorth: 500)
        let hood = Self.squareHood(id: "no-places", center: center, isTouristTrap: false)
        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute, destinationHoodID: "destination", hoods: [hood], places: []
        )
        let candidate = try #require(result.first)
        #expect(candidate.coordinate.latitude == center.latitude)
        #expect(candidate.curatedPlaceCount == 0)
    }

    @Test("ranking is curated-place count desc, then off-route distance asc, then hood id asc")
    func rankingOrder() {
        let moreePlaces = Self.squareHood(id: "b-more-places", center: Self.pointNearRoute(metersNorth: 600), isTouristTrap: false)
        let fewerPlacesCloser = Self.squareHood(id: "a-fewer-places-closer", center: Self.pointNearRoute(metersNorth: 300), isTouristTrap: false)
        let fewerPlacesFarther = Self.squareHood(id: "c-fewer-places-farther", center: Self.pointNearRoute(metersNorth: 700), isTouristTrap: false)

        let places = [
            Self.makePlace(id: "p1", hoodID: "b-more-places", coordinate: Self.pointNearRoute(metersNorth: 600)),
            Self.makePlace(id: "p2", hoodID: "b-more-places", coordinate: Self.pointNearRoute(metersNorth: 610)),
        ]

        let result = ScenicWaypointPlanner.candidates(
            alongFastRoute: Self.straightRoute,
            destinationHoodID: "destination",
            hoods: [moreePlaces, fewerPlacesCloser, fewerPlacesFarther],
            places: places
        )

        #expect(result.map(\.hood.id) == ["b-more-places", "a-fewer-places-closer", "c-fewer-places-farther"])
    }
}
