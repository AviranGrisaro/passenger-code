/// Pure VoiceOver string composition (passport TRD §4.7, D12, req 7) —
/// unit-tested over the full matrix, no simulator and no VoiceOver session
/// needed to prove the strings. Clause order follows
/// `map-rendering-spec.md` §7's established construction.
enum PassportLabels {
    /// "Dr. Shakshuka, triangle sticker" — the sticker's **shape** word
    /// (D12), never the raw `place_type`. `StickerShape.spokenName` is the
    /// only source; T-042 §3.1 keeps `place_type` itself off every
    /// user-facing surface, and this label does not reopen that.
    static func sticker(placeName: String, shape: StickerShape) -> String {
        "\(placeName), \(shape.spokenName) sticker"
    }

    /// "Kerem HaTeimanim, 2 of 2 places, Local reached"
    /// "Florentin, 0 of 2 places, not yet Local"
    static func hoodProgress(hoodName: String, beenCount: Int, threshold: Int, isLocal: Bool) -> String {
        let status = isLocal ? "Local reached" : "not yet Local"
        return "\(hoodName), \(beenCount) of \(threshold) places, \(status)"
    }

    /// "Local in every neighbourhood" / "Local in 1 of 3 neighbourhoods".
    /// Callers only render this when `designatedCount > 0` (TRD §4.3's
    /// overall line — "renders only when at least one Hood is designated"),
    /// so the empty-set guard below is defensive, not a case any caller
    /// should reach: without it, `0 == 0` would say "every neighbourhood"
    /// for a screen with no designated Hoods at all — the exact answer
    /// `PassportComposition.isOverallLocal` exists to prevent (TRD §4.1).
    static func overall(localCount: Int, designatedCount: Int) -> String {
        guard designatedCount > 0 else { return "Local in 0 of 0 neighbourhoods" }
        return localCount == designatedCount
            ? "Local in every neighbourhood"
            : "Local in \(localCount) of \(designatedCount) neighbourhoods"
    }
}
