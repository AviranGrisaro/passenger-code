import CoreLocation

/// One curated place, decoded once per session and never mutated after
/// (TRD §3.2, §4.4). `Places/` knows no SwiftUI and no map view types — this
/// type is identity and geometry, same discipline as `Hood` (TRD §2.2).
///
/// Stays exactly this five-field shape in this task by TRD decision (§8 D7):
/// `placeType`, `keywords`, `permanentlyClosed`, `isTouristTrap` each land in
/// the task that first reads them (T-037/T-038/T-036/T-035), not here. A
/// field with no reader in this task is exactly what D2's "don't build for a
/// feature that isn't specced yet" forbids.
struct Place: Identifiable, Sendable {
    let id: String
    let name: String
    let category: PlaceCategory
    let hoodID: String
    let coordinate: CLLocationCoordinate2D
}

extension Place: Hashable {
    // Same reason as `Hood`: `CLLocationCoordinate2D` is not `Hashable`.
    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
