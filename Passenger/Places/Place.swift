import CoreLocation

/// One curated place, decoded once per session and never mutated after
/// (TRD §3.2, §4.4). `Places/` knows no SwiftUI and no map view types — this
/// type is identity and geometry, same discipline as `Hood` (TRD §2.2).
///
/// `placeType`, `keywords` still land in the task that first reads them
/// (T-037/T-038) — a field with no reader is exactly what D2's "don't build
/// for a feature that isn't specced yet" forbids.
/// `permanentlyClosed` is one exception: `places-been-saved` (T-036) is the
/// task that reads it, and it is added here, non-optional, threaded through
/// all three of `PlaceCatalog`'s source paths (places-been-saved TRD §3.2,
/// D1) — a missing value is a decode failure with a designed fallback, never
/// a silent `false`. `isTouristTrap` is the other: tourist-trap-flag (T-035)
/// reads it, and it is `Bool?` — `nil` == not yet rated, three states not a
/// boolean, matching `Hood.isTouristTrap` (tourist-trap-flag TRD §3.1).
struct Place: Identifiable, Sendable {
    let id: String
    let name: String
    let category: PlaceCategory
    let hoodID: String
    let coordinate: CLLocationCoordinate2D
    let permanentlyClosed: Bool
    /// Defaulted (not just optional) so every existing call site that
    /// predates this field — `Place` is never `Decodable`, it's always
    /// hand-constructed — keeps compiling without a mechanical touch-up.
    var isTouristTrap: Bool? = nil
}

extension Place: Hashable {
    // Same reason as `Hood`: `CLLocationCoordinate2D` is not `Hashable`.
    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
