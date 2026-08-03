/// The Local threshold — one declaration site, app-wide (passport TRD §4.2,
/// D6). PRD req 4: "read from configuration, not hardcoded per Hood." There
/// is no per-Hood override and no second comparison against a Been count
/// anywhere in this feature (§9 row 4) — `HoodProgress.isLocal` is the only
/// caller of `isLocal(beenCount:)`.
enum LocalStatus {
    /// **[ASSUMPTION] — provisional, Aviran's or `data-engineer`'s to set**
    /// (TRD §4.2, D6). The value is not a product judgement: it is chosen
    /// for observability against the data that actually ships in Build
    /// Phase 1 — with T-036's two-Been fixture (both in `kerem-hateimanim`)
    /// and A2's three designated Hoods, a threshold of 2 makes Local,
    /// partial-zero, and overall-not-reached all reachable on a real
    /// device. One line to change once a real value is ratified.
    static let threshold = 2

    static func isLocal(beenCount: Int) -> Bool {
        beenCount >= threshold
    }
}
