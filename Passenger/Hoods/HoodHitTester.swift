import MapKit

/// Pure geometry: point → Hood?, with a caller-supplied hit-tolerance (TRD §4.3,
/// design spec §8 item 1). Takes no MapKit view type — `MapReader` supplies the
/// screen→coordinate conversion in `MapScreen`; this type never sees a gesture
/// or a camera.
///
/// Ray casting runs in `MKMapPoint`'s projected plane, never in raw degrees.
/// Containment (even-odd ray casting) is topologically robust in *any*
/// consistent 2D coordinate mapping, including raw lat/long — that part would
/// work in degrees too. What genuinely needs the projected space is the
/// **tolerance distance**: at Tel Aviv's latitude, 1° longitude is shorter than
/// 1° latitude by roughly cos(latitude) ≈ 0.85, so a fixed-degree tolerance
/// would be an anisotropic ellipse, not a circle. `MKMapPoint`'s Mercator-style
/// projection is locally conformal (uniform scale in every direction), which is
/// what makes a single scalar `tolerance` meaningful at all
/// (`ios-code-reviewer`'s trd-review correction to the TRD's stated rationale).
struct HoodHitTester: Sendable {
    private let hoods: [Hood]

    init(hoods: [Hood]) {
        self.hoods = hoods
    }

    /// - Parameter tolerance: map-point distance equivalent to 22pt at the
    ///   current camera (half the 44pt minimum target — TRD §4.3 point 2).
    ///   `MapScreen` derives this per-tap from the live camera so it self-corrects
    ///   for zoom and latitude, rather than a value computed once and gone stale.
    func hood(at point: MKMapPoint, tolerance: Double) -> Hood? {
        // Pass 1: bounding-rect prefilter, then even-odd ray casting against the
        // containing candidates. Hoods don't overlap (PRD req 3), so at most one
        // hit is possible here.
        if let hit = hoods.first(where: { $0.boundingRect.contains(point) && Self.contains(point: point, ring: $0.ring) }) {
            return hit
        }

        // Pass 2: on a miss, the nearest Hood whose edge lies within `tolerance`
        // wins — this is how the 44pt minimum touch target (design §4) is met
        // without dilating the drawn shape; the hit area extends past the
        // boundary, the fill does not. Checked against every Hood, not just
        // bbox candidates, since a thin sliver Hood's own bbox can be smaller
        // than the tolerance radius.
        //
        // Tie-break: a tap equidistant from two adjacent Hoods (a shared
        // boundary or a 3-Hood corner) resolves to whichever Hood appears
        // first in `hoods` — stable and deterministic, not an accident of
        // dictionary/set ordering (`ios-code-reviewer`'s trd-review 6th test case).
        var best: (hood: Hood, distance: Double)?
        for hood in hoods {
            let distance = Self.distanceToEdge(point: point, ring: hood.ring)
            guard distance <= tolerance else { continue }
            if best == nil || distance < best!.distance {
                best = (hood, distance)
            }
        }
        return best?.hood
    }

    /// Standard even-odd ray-casting polygon-containment test.
    private static func contains(point: MKMapPoint, ring: [MKMapPoint]) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let vi = ring[i]
            let vj = ring[j]
            if (vi.y > point.y) != (vj.y > point.y) {
                let crossingX = (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x
                if point.x < crossingX {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }

    /// Shortest distance from `point` to the polygon's boundary (its edges),
    /// not its interior — only ever consulted on a containment miss.
    private static func distanceToEdge(point: MKMapPoint, ring: [MKMapPoint]) -> Double {
        guard ring.count >= 2 else { return .infinity }
        var minDistance = Double.infinity
        var j = ring.count - 1
        for i in 0..<ring.count {
            minDistance = min(minDistance, distance(point: point, segmentStart: ring[j], segmentEnd: ring[i]))
            j = i
        }
        return minDistance
    }

    private static func distance(point: MKMapPoint, segmentStart a: MKMapPoint, segmentEnd b: MKMapPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - a.x, point.y - a.y)
        }
        var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared
        t = max(0, min(1, t))
        let projectedX = a.x + t * dx
        let projectedY = a.y + t * dy
        return hypot(point.x - projectedX, point.y - projectedY)
    }
}
