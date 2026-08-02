/// The three zoom tiers `map-rendering-spec.md` §2 needs for the tourist-trap
/// flag (TRD §2.3). Single source of truth: nothing else in the app may
/// re-derive a tier from a camera span — the map never asks the flag a
/// question it can answer two ways (TRD §2.2).
enum MapZoomTier: Equatable {
    case cityWide
    case neighborhood
    case close

    /// Renamed in place from `MapScreen.nameLabelSpanThreshold` (TRD §2.3) —
    /// no existing behaviour moves, since `tier == .close` is exactly
    /// `span < closeSpanThreshold`, the same comparison `showsNames` already
    /// made under its old name.
    static let closeSpanThreshold: Double = 0.06

    /// New (TRD §2.3): strictly between `closeSpanThreshold` (0.06) and the
    /// cold-open span (0.14) — the exact value is `ios-developer`'s call,
    /// same carve-out T-031 made for heat-band thresholds.
    static let neighborhoodSpanThreshold: Double = 0.10

    /// | Tier | Span |
    /// |---|---|
    /// | `.cityWide` | `span >= neighborhoodSpanThreshold` |
    /// | `.neighborhood` | `closeSpanThreshold <= span < neighborhoodSpanThreshold` |
    /// | `.close` | `span < closeSpanThreshold` |
    static func tier(forLatitudeDelta latitudeDelta: Double) -> MapZoomTier {
        if latitudeDelta < closeSpanThreshold {
            .close
        } else if latitudeDelta < neighborhoodSpanThreshold {
            .neighborhood
        } else {
            .cityWide
        }
    }
}
