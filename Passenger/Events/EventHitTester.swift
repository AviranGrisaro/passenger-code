import MapKit

/// Pure geometry: point → nearest `LiveEvent` within tolerance (TRD §4.5,
/// D7). Mirrors `PlaceHitTester` exactly — same seam discipline, testable
/// without a map or a simulator, and the same nearest-within-tolerance
/// contract.
struct EventHitTester: Sendable {
    private let events: [LiveEvent]

    init(events: [LiveEvent]) {
        self.events = events
    }

    /// Nearest event whose coordinate lies within `tolerance` of `point`. A
    /// marker is a point, not a polygon — every candidate is a distance
    /// check, exactly `PlaceHitTester.place(at:tolerance:)`'s own rule.
    ///
    /// Tie-break: a tap equidistant from two events resolves to whichever
    /// appears first in `events` — stable and deterministic, matching
    /// `PlaceHitTester`'s and `HoodHitTester`'s own tie-break rule.
    func event(at point: MKMapPoint, tolerance: Double) -> LiveEvent? {
        var best: (event: LiveEvent, distance: Double)?
        for candidate in events {
            let candidatePoint = MKMapPoint(candidate.coordinate)
            let distance = point.distance(to: candidatePoint)
            guard distance <= tolerance else { continue }
            if best == nil || distance < best!.distance {
                best = (candidate, distance)
            }
        }
        return best?.event
    }
}
