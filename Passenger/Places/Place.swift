import CoreLocation

/// One curated place, decoded once per session and never mutated after
/// (TRD §3.2, §4.4). `Places/` knows no SwiftUI and no map view types — this
/// type is identity and geometry, same discipline as `Hood` (TRD §2.2).
///
/// `permanentlyClosed` is one of four wider `places` columns each assigned to
/// the task that first reads it (T-042 §3 D5): `places-been-saved` (T-036)
/// reads this one, and it is added here, non-optional, threaded through all
/// three of `PlaceCatalog`'s source paths (places-been-saved TRD §3.2, D1) —
/// a missing value is a decode failure with a designed fallback, never a
/// silent `false`. `isTouristTrap` is another: tourist-trap-flag (T-035)
/// reads it, and it is `Bool?` — `nil` == not yet rated, three states not a
/// boolean, matching `Hood.isTouristTrap` (tourist-trap-flag TRD §3.1).
/// `placeType` is the third: passport (T-037) reads it, non-optional
/// `String` (passport TRD §3.2, D2) — not a Swift enum, because T-042
/// deliberately made `place_type` a table rather than a Postgres enum so
/// adding a value is an insert, not a migration; a closed client enum here
/// would turn that insert into a dropped row at the decode boundary. The
/// closed set lives one hop later, on `StickerShape`, where an unknown value
/// degrades to a generic sticker instead of deleting a place.
/// `keywords` is the fourth and last: search-quick-filters (T-038) reads it,
/// non-optional `[String]`, threaded through the same three source paths the
/// same way (search-quick-filters TRD §3.2) — an absent key is a decode
/// failure, but an *empty* array is a real value (a place matching no
/// keyword), not a decode failure.
struct Place: Identifiable, Sendable {
    let id: String
    let name: String
    let category: PlaceCategory
    let hoodID: String
    let coordinate: CLLocationCoordinate2D
    let permanentlyClosed: Bool
    let placeType: String
    /// Defaulted (not just optional) so every existing call site that
    /// predates this field — `Place` is never `Decodable`, it's always
    /// hand-constructed — keeps compiling without a mechanical touch-up.
    var isTouristTrap: Bool? = nil
    /// Defaulted to `[]` for the same reason `isTouristTrap` is defaulted —
    /// every pre-existing hand-constructed `Place(...)` call site keeps
    /// compiling. No decode path relies on this default: all three
    /// `Decodable` shapes declare the key non-optional with no default, so a
    /// missing key is a real decode failure there, not this convenience
    /// default leaking in.
    var keywords: [String] = []
}

extension Place: Hashable {
    // Same reason as `Hood`: `CLLocationCoordinate2D` is not `Hashable`.
    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
