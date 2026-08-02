/// Every user-facing and spoken string for the tourist-trap flag, in one
/// place (TRD §4.2). Public-facing copy is "tourist-heavy spot"
/// (`strategy/decisions.md` #42) — never "tourist trap," and never one of
/// decision #18's retired three-way vibe-tag words ("touristy", "mix"/
/// "mixed", "super local"), which would silently resurrect a graduated scale
/// this feature replaced with a boolean (PRD req 1).
enum FlagCopy {
    // MARK: - Hood centroid label (`.neighborhood` zoom tier only, TRD §2.3)

    /// `nil` when nothing should render — not-flagged and unrated both stay
    /// silent here (req 4's "renders no stroke" extends to the label).
    static func centroidLabel(flag: TouristFlag, band: HeatBand?) -> String? {
        guard flag == .flagged else { return nil }
        return band == .busy ? "Busy and tourist-heavy" : "Tourist-heavy spot"
    }

    // MARK: - Place-detail-modal line (TRD §4.2 row 2, `PlaceDetailModal.touristTrapSlot`)

    /// Rendered only when `place.isTouristTrap == true` — nothing otherwise.
    static let placeLine = "Tourist-heavy spot"

    // MARK: - Hood-sheet line (D5) — three states, always present

    static func hoodSheetLine(flag: TouristFlag) -> String {
        switch flag {
        case .flagged: "Tourist-heavy spot"
        case .notFlagged: "Not a tourist-heavy spot"
        case .unrated: "No local rating yet"
        }
    }

    // MARK: - Local-QA toast question (TRD §4.3)

    static let toastQuestion = "Does this feel like a tourist-heavy spot?"
    static let toastYes = "Yes"
    static let toastNo = "No"
}
