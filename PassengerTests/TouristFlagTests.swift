import Testing
@testable import Passenger

/// tourist-trap-flag TRD §9 rows 1, 2, 4, 5 — the full 3×4 matrix
/// (`TouristFlag` × `HeatBand?`), covering §4.1's table verbatim.
@Suite("TouristFlag / FlagStroke")
struct TouristFlagTests {
    @Test("Bool? maps onto the three states")
    func initFromOptionalBool() {
        #expect(TouristFlag(true) == .flagged)
        #expect(TouristFlag(false) == .notFlagged)
        #expect(TouristFlag(nil) == .unrated)
    }

    @Test("FlagStroke has exactly 3 cases — row 1a")
    func flagStrokeHasThreeCases() {
        #expect(FlagStroke.allCases.count == 3)
    }

    // §4.1's table, verbatim: `.notFlagged` and `.unrated` are identical in
    // every band column (req 4); `.flagged` is `.plain` except at `.busy`,
    // where it's `.busyWarning` (req 5 — replaces, never stacks).
    @Test("treatment(for:band:) matches §4.1's table, all 3×4 cells")
    func treatmentMatchesTable() {
        let table: [(TouristFlag, HeatBand?, FlagStroke)] = [
            (.flagged, nil, .plain),
            (.flagged, .quiet, .plain),
            (.flagged, .moderate, .plain),
            (.flagged, .busy, .busyWarning),
            (.notFlagged, nil, .none),
            (.notFlagged, .quiet, .none),
            (.notFlagged, .moderate, .none),
            (.notFlagged, .busy, .none),
            (.unrated, nil, .none),
            (.unrated, .quiet, .none),
            (.unrated, .moderate, .none),
            (.unrated, .busy, .none),
        ]
        for (flag, band, expected) in table {
            #expect(FlagStroke.treatment(for: flag, band: band) == expected)
        }
    }

    @Test("not-flagged and not-yet-rated are identical in every band column — row 4a")
    func notFlaggedAndUnratedAreIdentical() {
        for band: HeatBand? in [nil, .quiet, .moderate, .busy] {
            #expect(FlagStroke.treatment(for: .notFlagged, band: band) == FlagStroke.treatment(for: .unrated, band: band))
        }
    }

    @Test("busy+flagged replaces the plain treatment outright — never both (row 5a)")
    func busyReplacesPlainOutright() {
        // A single-value return, not a set — stacking is unrepresentable by
        // the type itself (§8 D2).
        let atBusy = FlagStroke.treatment(for: .flagged, band: .busy)
        #expect(atBusy == .busyWarning)
        #expect(atBusy != .plain)
    }

    @Test("the flagged set never changes with the band — only style does (D3, row 2c)")
    func flaggedSetIsHourInvariant() {
        // For every band, a flagged Hood always has SOME non-.none
        // treatment, and a not-flagged/unrated Hood never does.
        for band: HeatBand? in [nil, .quiet, .moderate, .busy] {
            #expect(FlagStroke.treatment(for: .flagged, band: band) != .none)
            #expect(FlagStroke.treatment(for: .notFlagged, band: band) == .none)
            #expect(FlagStroke.treatment(for: .unrated, band: band) == .none)
        }
    }
}
