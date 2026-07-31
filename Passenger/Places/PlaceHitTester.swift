import MapKit

/// Pure geometry: point → nearest `Place` within tolerance (TRD §4.5). Takes
/// no MapKit view type — the same seam discipline as `HoodHitTester`,
/// testable without a map or a simulator.
struct PlaceHitTester: Sendable {
    private let places: [Place]

    init(places: [Place]) {
        self.places = places
    }

    /// Nearest place whose coordinate lies within `tolerance` of `point`
    /// (TRD §4.5) — a pin is a point, not a polygon, so there is no
    /// containment pass the way `HoodHitTester` has one; every candidate is a
    /// distance check.
    ///
    /// Tie-break: a tap equidistant from two places resolves to whichever
    /// appears first in `places` — stable and deterministic, matching
    /// `HoodHitTester`'s own tie-break rule, not an accident of ordering.
    func place(at point: MKMapPoint, tolerance: Double) -> Place? {
        var best: (place: Place, distance: Double)?
        for candidate in places {
            let candidatePoint = MKMapPoint(candidate.coordinate)
            let distance = point.distance(to: candidatePoint)
            guard distance <= tolerance else { continue }
            if best == nil || distance < best!.distance {
                best = (candidate, distance)
            }
        }
        return best?.place
    }
}
