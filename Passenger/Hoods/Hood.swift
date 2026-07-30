import CoreLocation
import MapKit

/// One neighborhood polygon, decoded once from the bundled catalog and never
/// mutated after (TRD §3.2, §4.2). `Hoods/` knows no network and no density
/// (TRD §2.2) — this type is pure geometry plus identity.
///
/// `Sendable` here rests on `MKMapPoint`/`MKMapRect`/`CLLocationCoordinate2D`
/// all being plain-`Double` value types the iOS 26 SDK marks `Sendable` —
/// checked at `trd-review` (`ios-code-reviewer`'s finding) and confirmed here by
/// the fact that this file, and `HoodCatalog.load()` running off the main actor
/// and handing a `[Hood]` across the actor boundary in `MapScreen`, compile
/// clean under `SWIFT_STRICT_CONCURRENCY = complete` with no `@unchecked`
/// escape hatch. If a future SDK ever un-marks one of those types, this
/// conformance will fail to compile here first, not silently misbehave.
struct Hood: Identifiable, Sendable {
    let id: String
    let name: String
    let ring: [MKMapPoint]
    let boundingRect: MKMapRect
    let centroid: CLLocationCoordinate2D

    /// For `MapPolygon(coordinates:)` — `Map/` is the only layer that touches
    /// raw coordinates for rendering; `Hoods/`'s own hit-testing stays in the
    /// projected `MKMapPoint` plane (TRD §4.3).
    var coordinates: [CLLocationCoordinate2D] {
        ring.map(\.coordinate)
    }
}

extension Hood: Hashable {
    // `CLLocationCoordinate2D` has no `Equatable`/`Hashable` conformance of its
    // own, so this can't synthesize — hash and compare on `id`, the stable slug
    // identity the PRD already guarantees is unique.
    static func == (lhs: Hood, rhs: Hood) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
