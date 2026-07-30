/// Discrete density step. No `.none` case — "no data" is the absence of an
/// entry in `DensitySnapshot`, not a band value (TRD §3.1, §4.1). `HeatBand?`
/// carries that distinction the map has to render silently (PRD req 7).
///
/// Band count is locked at 3 (quiet/moderate/busy) — `map-rendering-spec.md`
/// L42 already couples a sibling feature (tourist-trap-flag) to a *named*
/// band called "busy," and `data-engineer`'s B1 call is thresholds only, not
/// count (BOARD.md T-031, architect's post-trd-review amendment).
enum HeatBand: Int, Sendable, CaseIterable, Codable {
    case quiet = 1
    case moderate = 2
    case busy = 3

    /// Spoken form for VoiceOver (design spec §4 — "Florentin, busy").
    var spokenWord: String {
        switch self {
        case .quiet: "quiet"
        case .moderate: "moderate"
        case .busy: "busy"
        }
    }
}
