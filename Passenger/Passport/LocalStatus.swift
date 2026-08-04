/// The Local threshold — one declaration site, app-wide (passport TRD §4.2,
/// D6). PRD req 4: "read from configuration, not hardcoded per Hood." There
/// is no per-Hood override and no second comparison against a Been count
/// anywhere in this feature (§9 row 4) — `HoodProgress.isLocal` is the only
/// caller of `isLocal(beenCount:)`.
enum LocalStatus {
    /// **Confirmed 2026-08-04 — decision #45** (`product`, T-048/`PAS-35`;
    /// passport TRD §4.2, D6). No longer provisional and no longer
    /// Aviran's to set. The value is a product judgement, not a
    /// fixture-observability pick: Local per Hood means you came back, not
    /// that you completed the Hood. The range was fixed by data before
    /// taste entered — floor 2 (at 1, Local is true on first contact and
    /// overall Local degrades into a checklist), ceiling 3 (the smallest
    /// curated-place count across the three designated Hoods —
    /// `florentin`, `kerem-hateimanim`, `neve-tzedek`, confirmed as the
    /// real designated set by T-047/`PAS-34`, not a placeholder). 3 was
    /// rejected within that range: it equals 100% catalogue completion,
    /// leaving no margin for a number that gates dataset validation, and
    /// one closed place would make a Hood Local-unreachable. The former
    /// observability argument still holds as a consequence, not the
    /// reason: with T-036's two-Been fixture (both in
    /// `kerem-hateimanim`) and the three designated Hoods, 2 keeps Local,
    /// partial-zero, and overall-not-reached all reachable on a real
    /// device. **Review trigger:** re-derive if the curated-place count
    /// per designated Hood drifts outside roughly 3-6, or if the
    /// designated set changes (decision #45).
    static let threshold = 2

    static func isLocal(beenCount: Int) -> Bool {
        beenCount >= threshold
    }
}
