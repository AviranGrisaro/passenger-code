import CoreLocation
import MapKit

/// One neighborhood polygon, decoded once from the bundled catalog and never
/// mutated after (TRD §3.2, §4.2). `Hoods/` knows no network and no density
/// (TRD §2.2) — this type is geometry, identity, and the three curated
/// attributes that ride along in the same bundle (hood-dataset TRD §4.3).
/// It renders nothing and adds no behaviour: T-033/T-035/T-037 are the
/// consumers of `blurb`/`isTouristTrap`/`designatedForProgression`, not this
/// task (hood-dataset TRD §4.3).
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
    /// Read from the bundle when the generator precomputed it (§8 D5); falls
    /// back to `HoodCatalog`'s averaged-vertex centroid when the bundle omits
    /// it, so a stale (pre-D5) bundle still loads (§4.3 decode rules).
    let centroid: CLLocationCoordinate2D
    /// `nil` == not curated, never a placeholder empty string (§3.1, §4.3).
    let blurb: String?
    /// `nil` == not yet rated — three states, not a boolean (§3.1).
    let isTouristTrap: Bool?
    /// No `nil` state: an undesignated Hood carries `false` explicitly (§3.1).
    let designatedForProgression: Bool

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
