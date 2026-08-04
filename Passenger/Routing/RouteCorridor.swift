import CoreLocation
import MapKit

/// Pure geometry: point→polyline distance, the divergence run, and the seam
/// dedup (TRD §4.2, §4.5, §5) — over `MKMapPoint`'s projected plane, the
/// same discipline `HoodHitTester` already uses (TRD §2.3: "all three are
/// ≤ 20 lines over `MKMapPoint`'s flat projected plane"). Every distance
/// this type returns is in real metres, converted from the projected plane
/// via `MKMetersPerMapPointAtLatitude` at the query point's own latitude —
/// Tel Aviv's corridor never spans enough latitude for that single-point
/// conversion to matter.
enum RouteCorridor {
    /// Shortest distance, in metres, from `point` to the polyline described
    /// by `coordinates` — the minimum over every consecutive segment, not
    /// just the nearest vertex. Fewer than 2 coordinates has no segment to
    /// measure against and returns `.infinity`, never a false zero.
    static func distance(from point: CLLocationCoordinate2D, toPolyline coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard coordinates.count >= 2 else { return .infinity }
        let target = MKMapPoint(point)
        var minMapPointDistance = Double.infinity
        for index in 1..<coordinates.count {
            let segmentStart = MKMapPoint(coordinates[index - 1])
            let segmentEnd = MKMapPoint(coordinates[index])
            minMapPointDistance = min(minMapPointDistance, distanceToSegment(point: target, segmentStart: segmentStart, segmentEnd: segmentEnd))
        }
        return minMapPointDistance * MKMetersPerMapPointAtLatitude(point.latitude)
    }

    /// Shortest distance, in metres, between a closed ring (a Hood's
    /// polygon, TRD §4.5 filter 3) and an open polyline (the fast route) —
    /// the minimum over both directions: every ring vertex to the nearest
    /// polyline segment, and every polyline vertex to the nearest ring edge
    /// (including the ring's own closing edge, last vertex back to first).
    /// Bidirectional because a long, sparse ring edge can pass close to a
    /// polyline without any single ring *vertex* being close to it.
    static func distance(betweenRing ring: [CLLocationCoordinate2D], andPolyline polyline: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard !ring.isEmpty, polyline.count >= 2 else { return .infinity }
        let ringToPolyline = ring.map { distance(from: $0, toPolyline: polyline) }.min() ?? .infinity
        let closedRing = ring + [ring[0]]
        let polylineToRing = polyline.map { distance(from: $0, toPolyline: closedRing) }.min() ?? .infinity
        return min(ringToPolyline, polylineToRing)
    }

    /// Seam dedup (TRD §4.2): `first ++ second`, dropping `second`'s first
    /// coordinate when it lies within 5 m of `first`'s last. Both legs'
    /// endpoints derive from the same requested waypoint, but MapKit snaps
    /// each independently to the pedestrian network, so byte-equality at the
    /// seam is not guaranteed and an undeduped seam draws a visible
    /// one-point spur.
    static func concatenate(_ first: [CLLocationCoordinate2D], _ second: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard let lastOfFirst = first.last, let firstOfSecond = second.first else {
            return first + second
        }
        let seamMapPointDistance = MKMapPoint(lastOfFirst).distance(to: MKMapPoint(firstOfSecond))
        let seamMeters = seamMapPointDistance * MKMetersPerMapPointAtLatitude(lastOfFirst.latitude)
        let tail = seamMeters <= 5 ? Array(second.dropFirst()) : second
        return first + tail
    }

    /// The divergence test (TRD §5, D8). Req 4's "if the scenic polyline
    /// comes back identical to the fast one, treat it as no scenic route"
    /// cannot be implemented as polyline equality — MapKit returns different
    /// point counts for the same path across requests, so an equality check
    /// would never fire and the requirement would pass by never being
    /// exercised. This is the falsifiable form instead: sample `scenic`
    /// every `sampleSpacing` metres, compute each sample's distance to the
    /// nearest `fast` segment, and require a contiguous run of samples
    /// beyond `tolerance` that covers at least `minimumRun` metres.
    static func diverges(
        _ scenic: [CLLocationCoordinate2D],
        from fast: [CLLocationCoordinate2D],
        minimumRun: Double,
        tolerance: Double,
        sampleSpacing: Double = 20
    ) -> Bool {
        let samples = sample(polyline: scenic, spacing: sampleSpacing)
        guard !samples.isEmpty else { return false }

        var currentRun = 0.0
        for point in samples {
            if distance(from: point, toPolyline: fast) > tolerance {
                currentRun += sampleSpacing
                if currentRun >= minimumRun { return true }
            } else {
                currentRun = 0
            }
        }
        return false
    }

    /// Points spaced roughly `spacing` metres apart along `polyline`,
    /// walking each segment in turn and always including the polyline's own
    /// vertices — a segment shorter than `spacing` still contributes its
    /// endpoint, so a short scenic polyline is never sampled zero times.
    private static func sample(polyline: [CLLocationCoordinate2D], spacing: Double) -> [CLLocationCoordinate2D] {
        guard polyline.count >= 2 else { return polyline }
        var result: [CLLocationCoordinate2D] = [polyline[0]]
        for index in 1..<polyline.count {
            let start = MKMapPoint(polyline[index - 1])
            let end = MKMapPoint(polyline[index])
            let segmentMeters = start.distance(to: end) * MKMetersPerMapPointAtLatitude(polyline[index - 1].latitude)
            guard segmentMeters > 0 else { continue }
            var walked = spacing
            while walked < segmentMeters {
                let t = walked / segmentMeters
                let x = start.x + t * (end.x - start.x)
                let y = start.y + t * (end.y - start.y)
                result.append(MKMapPoint(x: x, y: y).coordinate)
                walked += spacing
            }
            result.append(polyline[index])
        }
        return result
    }

    /// Same point-to-segment formula as `HoodHitTester.distance` — the
    /// projection of `point` onto the segment, clamped to the segment's
    /// extent.
    private static func distanceToSegment(point: MKMapPoint, segmentStart a: MKMapPoint, segmentEnd b: MKMapPoint) -> Double {
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
