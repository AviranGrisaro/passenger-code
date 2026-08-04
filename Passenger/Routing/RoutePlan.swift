import CoreLocation

/// Which of the two routes a `RoutePlan` describes (TRD §3.2).
enum RouteKind: Sendable, CaseIterable {
    case fast
    case scenic
}

/// One resolved walking route — fast, or a scenic detour through one Hood
/// (TRD §3.2, §4.2). Built from either 1 leg (`.fast`) or 2 concatenated legs
/// (`.scenic`, TRD §4.2) — this type carries only the result, never the legs
/// that produced it.
struct RoutePlan: Sendable {
    let kind: RouteKind
    /// Seam-deduped, ordered origin → destination (TRD §4.2).
    let coordinates: [CLLocationCoordinate2D]
    /// Metres, summed over legs.
    let distance: CLLocationDistance
    /// Seconds, summed over legs.
    let travelTime: TimeInterval
    /// Scenic only; `nil` for `.fast` (TRD §4.10's "via <Hood name>").
    let viaHoodName: String?
}

extension RoutePlan: Equatable {
    // `CLLocationCoordinate2D` has no `Equatable` conformance of its own
    // (TRD §3.2, "two conformance notes"), so this can't synthesize.
    static func == (lhs: RoutePlan, rhs: RoutePlan) -> Bool {
        lhs.kind == rhs.kind
            && lhs.coordinates.count == rhs.coordinates.count
            && zip(lhs.coordinates, rhs.coordinates).allSatisfy { $0.latitude == $1.latitude && $0.longitude == $1.longitude }
            && lhs.distance == rhs.distance
            && lhs.travelTime == rhs.travelTime
            && lhs.viaHoodName == rhs.viaHoodName
    }
}
