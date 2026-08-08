import XCTest

/// QA investigation, 2026-08-07 — chasing down an unconfirmed `designer`
/// finding on `agent-os/BOARD.md`'s Unowned findings inbox: while driving
/// `SearchOverlay` via raw `simctl` coordinate taps (for unrelated `PAS-77`
/// verification), tapping a search-result row repeatedly dismissed the
/// overlay instead of selecting the result. That could be a real
/// hit-testing/z-order bug in `SearchOverlay`'s result rows (see
/// `MapScreen.swift`'s z3 tap-catcher at line ~433 and z7 `MapNavRow` at
/// line ~538, both layered above/below the z5 `SearchOverlay` — `MapNavRow`
/// is explicitly documented as "always hit-testable ... drawn last ...
/// renders above all of them"), or it could be an artifact specific to
/// `simctl`-driven synthetic taps (coordinate/timing mismatch), not
/// reproducible via a real XCUITest `.tap()` on the located element.
///
/// **Confirmed 2026-08-07 (`qa`), via a real XCUITest `.tap()` on the
/// located element — not a `simctl`-driving artifact.** Both cases below
/// reproduce: the row is `isHittable == true` per the accessibility tree,
/// yet tapping it dismisses `SearchOverlay` (`onDismiss`/`dismissSearch()`)
/// instead of firing `onSelect`/`handleSearchResultSelection`. Root-cause
/// hypothesis: the single visible result row renders essentially flush
/// with the true screen bottom (measured frame ~(16, 826, 370, 44) in an
/// 874pt-tall window) — inside or adjacent to `MapNavRow`'s reserved
/// bottom band (`navRowBandHeight` = 32+52 = 84pt, `MapScreen.swift`
/// ~line 551/100 in `SearchOverlay.swift`), which is `z7`, drawn last, and
/// explicitly documented as "always hit-testable ... renders above all of
/// them" (`MapScreen.swift` ~line 539). `SearchOverlay.swift`'s own
/// `navRowBandHeight`/`gapAboveNavRow` reservation is applied to
/// `compactFraction` **only for the `.hour` segment** (see that file's
/// doc comment: "Scoped to `.hour` only — `.search`'s `resultsArea`
/// already scrolls arbitrarily long content and has no P0 tied to
/// `compactFraction`") — that assumption doesn't hold once a short result
/// list's rows land inside the unreserved bottom band, where `MapNavRow`
/// (or possibly the z3 tap-catcher, `MapScreen.swift` ~line 433 — either
/// is consistent with the observed dismissal) sits on top and wins the
/// hit test. Filed as a Linear bug — see `PROGRESS.md`'s 2026-08-07 `qa`
/// entry for the issue key. Kept as regression coverage rather than
/// deleted, since the finding is a real, reproduced bug.
final class SearchResultRowTapInvestigationTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let dismiss = alert.buttons["Don't Allow"]
            guard dismiss.exists else { return false }
            dismiss.tap()
            return true
        }
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    /// Same `openSearch()` construction as `SearchAccessibilityTests` —
    /// waits for the overlay's own "Search" field label, proving the
    /// overlay is actually live before proceeding.
    private func openSearch() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        let searchButton = app.buttons["Search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "SearchButton never appeared in MapNavRow")
        searchButton.tap()

        let fieldLabel = app.staticTexts["Search"]
        XCTAssertTrue(fieldLabel.waitForExistence(timeout: 5), "SearchOverlay never rendered — field label missing")
    }

    /// Tapping a place result row via a real XCUITest `.tap()` (which
    /// resolves the element's actual hittable point through the
    /// accessibility tree, not a raw screen coordinate) must open
    /// `PlaceDetailModal` — not dismiss `SearchOverlay`.
    func testTappingPlaceResultRowOpensDetailModalNotDismiss() {
        openSearch()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Anna Loulou")

        let placeRow = app.buttons["Anna Loulou Bar, place, Eat & Drink"]
        XCTAssertTrue(placeRow.waitForExistence(timeout: 5), "Place result row never appeared")
        XCTAssertTrue(placeRow.isHittable, "Row exists but XCUITest reports it not hittable — something else occupies its point")

        placeRow.tap()

        let detailTitle = app.staticTexts["placeDetailTitle"]
        let detailAppeared = detailTitle.waitForExistence(timeout: 5)

        let fieldLabel = app.staticTexts["Search"]
        let overlayStillPresent = fieldLabel.exists

        XCTAssertTrue(
            detailAppeared,
            "BUG REPRODUCED: tapping the place result row did not open PlaceDetailModal " +
            "(placeDetailTitle never appeared). SearchOverlay still present: \(overlayStillPresent)."
        )
        XCTAssertFalse(
            overlayStillPresent,
            "BUG REPRODUCED: SearchOverlay is still on screen after tapping a result row " +
            "— the tap dismissed the overlay instead of selecting the result."
        )
    }

    /// Same check against a Hood result row (different `SearchResult.kind`,
    /// different downstream destination — `HoodSheet`, not
    /// `PlaceDetailModal`) to rule out a kind-specific fix.
    func testTappingHoodResultRowOpensHoodSheetNotDismiss() {
        openSearch()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Florentin")

        let hoodRow = app.buttons["Florentin, Hood"]
        XCTAssertTrue(hoodRow.waitForExistence(timeout: 5), "Hood result row never appeared")
        XCTAssertTrue(hoodRow.isHittable, "Row exists but XCUITest reports it not hittable — something else occupies its point")

        hoodRow.tap()

        let hoodTitle = app.staticTexts["hoodSheetTitle"]
        let sheetAppeared = hoodTitle.waitForExistence(timeout: 5)

        let fieldLabel = app.staticTexts["Search"]
        let overlayStillPresent = fieldLabel.exists

        XCTAssertTrue(
            sheetAppeared,
            "BUG REPRODUCED: tapping the Hood result row did not open HoodSheet " +
            "(hoodSheetTitle never appeared). SearchOverlay still present: \(overlayStillPresent)."
        )
        XCTAssertFalse(
            overlayStillPresent,
            "BUG REPRODUCED: SearchOverlay is still on screen after tapping a Hood result row " +
            "— the tap dismissed the overlay instead of selecting the result."
        )
    }
}
