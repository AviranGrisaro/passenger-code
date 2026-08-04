import CoreLocation
import MapKit

/// One candidate Hood the scenic route could detour through, already ranked
/// (TRD §4.5).
struct WaypointCandidate: Sendable {
    let hood: Hood
    let coordinate: CLLocationCoordinate2D
    let curatedPlaceCount: Int
    /// The waypoint's own distance to the fast polyline, metres — the
    /// second ranking key (TRD §4.5c).
    let offRouteDistance: CLLocationDistance
}

extension WaypointCandidate: Equatable {
    // Same reason as `RoutePlan`/`RouteEndpoint`: `CLLocationCoordinate2D`
    // isn't `Equatable`.
    static func == (lhs: WaypointCandidate, rhs: WaypointCandidate) -> Bool {
        lhs.hood == rhs.hood
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.curatedPlaceCount == rhs.curatedPlaceCount
            && lhs.offRouteDistance == rhs.offRouteDistance
    }
}

/// The scenic-detour heuristic (TRD §4.5): candidate Hoods along the fast
/// route's own polyline, flagged not-a-tourist-trap, ranked so the search in
/// `RoutePreviewModel` can try the best candidate first.
enum ScenicWaypointPlanner {
    /// Filter chain, in order (TRD §4.5):
    /// 1. `hood.isTouristTrap == false` — `nil` is never eligible.
    /// 2. Not the destination's Hood, and not the Hood containing the fast
    ///    route's own first coordinate (the origin's Hood) — routing
    ///    "through" either is meaningless.
    /// 3. The Hood's ring comes within `RouteBounds.corridorBuffer` of the
    ///    fast polyline.
    /// 4. The waypoint's distance to the fast polyline is within
    ///    `[minimumOffRoute, maximumOffRoute]`.
    /// 5. Sorted by curated-place count desc, then off-route distance asc,
    ///    then `Hood.id` asc — total and deterministic.
    static func candidates(
        alongFastRoute route: [CLLocationCoordinate2D],
        destinationHoodID: String,
        hoods: [Hood],
        places: [Place]
    ) -> [WaypointCandidate] {
        guard let originCoordinate = route.first else { return [] }
        let originHoodID = HoodHitTester(hoods: hoods).hood(at: MKMapPoint(originCoordinate), tolerance: 0)?.id
        let placesByHood = Dictionary(grouping: places, by: \.hoodID)

        return hoods
            .filter { $0.isTouristTrap == false }
            .filter { $0.id != destinationHoodID }
            .filter { hood in originHoodID.map { hood.id != $0 } ?? true }
            .compactMap { hood -> WaypointCandidate? in
                let ringDistance = RouteCorridor.distance(betweenRing: hood.coordinates, andPolyline: route)
                guard ringDistance <= RouteBounds.corridorBuffer else { return nil }

                let curatedPlaces = placesByHood[hood.id] ?? []
                let waypointCoordinate = nearestPlace(in: curatedPlaces, toPolyline: route)?.coordinate ?? hood.centroid
                let waypointDistance = RouteCorridor.distance(from: waypointCoordinate, toPolyline: route)
                guard waypointDistance >= RouteBounds.minimumOffRoute, waypointDistance <= RouteBounds.maximumOffRoute else { return nil }

                return WaypointCandidate(
                    hood: hood,
                    coordinate: waypointCoordinate,
                    curatedPlaceCount: curatedPlaces.count,
                    offRouteDistance: waypointDistance
                )
            }
            .sorted(by: isRankedBefore)
    }

    /// The candidate Hood's curated place nearest the fast polyline (TRD
    /// §4.5b) — `nil` when the Hood has no curated place, so the caller
    /// falls back to `hood.centroid`.
    private static func nearestPlace(in places: [Place], toPolyline route: [CLLocationCoordinate2D]) -> Place? {
        places.min { lhs, rhs in
            RouteCorridor.distance(from: lhs.coordinate, toPolyline: route)
                < RouteCorridor.distance(from: rhs.coordinate, toPolyline: route)
        }
    }

    private static func isRankedBefore(_ lhs: WaypointCandidate, _ rhs: WaypointCandidate) -> Bool {
        if lhs.curatedPlaceCount != rhs.curatedPlaceCount { return lhs.curatedPlaceCount > rhs.curatedPlaceCount }
        if lhs.offRouteDistance != rhs.offRouteDistance { return lhs.offRouteDistance < rhs.offRouteDistance }
        return lhs.hood.id < rhs.hood.id
    }
}
