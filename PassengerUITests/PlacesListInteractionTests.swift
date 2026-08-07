import XCTest

/// QA pass (T-036/PAS-27, round 8, 2026-08-04) — live coverage for the four
/// items round-7 code-review (`ios-code-reviewer`) explicitly briefed `qa`
/// to check "live, not just by code read": the three dismissal paths on the
/// Places list overlay, the D8 co-presentation guard (a `NavSurface` and a
/// system sheet are never co-presented, in either direction), and the
/// permanently-closed badge never disabling the place-detail modal's
/// Directions button. Written because manual simulator interaction in this
/// QA session was unreliable under severe concurrent host load (multiple
/// other agent sessions' `xcodebuild` processes drove `uptime` load averages
/// to 200-800 on a 10-core machine for over 30 minutes) while XCUITest's own
/// synthesized touches — going through the app's linked XCTest framework
/// rather than external simulator touch injection — worked reliably
/// throughout. A live UI test closes the same gap a manual click-through
/// would have, and remains as permanent regression coverage afterward.
///
/// Uses the shipped Build-Phase-1 fixture (`places-tel-aviv.json` +
/// `place-visits-tel-aviv.json`), unmodified — `neve-nachum-gutman-museum`
/// ships `permanently_closed: true` with a `visited` provenance entry, so it
/// is always present on the list without any setup. Location is denied via
/// the same `addUIInterruptionMonitor` pattern `DetailSheetInteractionTests`
/// already uses — Places reads no location, so this is orthogonal to every
/// assertion below (also, incidentally, re-confirms PRD req 5's "list still
/// opens and shows rows with location denied" on a live device).
final class PlacesListInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    /// `PlacesRowLabel.label` for the closed museum (`PlacesRowLabel.swift`'s
    /// own doc-comment example, verified against the live fixture record
    /// before writing this test: category `things-to-do` → "Things to do",
    /// provenance `visited` → "Visited", `permanently_closed: true` appends
    /// the closed clause).
    private let closedRowLabel = "Nachum Gutman Museum, Things to do, Visited, permanently closed"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let dismiss = alert.buttons["Don't Allow"]
            guard dismiss.exists else { return false }
            dismiss.tap()
            return true
        }

        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Closed badge never disables Directions (TRD §9 row 4b)

    func testClosedPlaceRowOpensDetailWithDirectionsEnabledNotBlocked() {
        app.buttons["Places"].tap()

        let closedRow = app.buttons[closedRowLabel]
        XCTAssertTrue(closedRow.waitForExistence(timeout: 5), "Closed-place row never rendered — expected \(closedRowLabel)")
        closedRow.tap()

        let title = app.staticTexts["placeDetailTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "PlaceDetailModal never opened from the closed row")
        XCTAssertEqual(title.label, "Nachum Gutman Museum")

        let directions = app.buttons["Directions"]
        XCTAssertTrue(directions.waitForExistence(timeout: 5), "Directions button missing on a closed place's modal")
        XCTAssertTrue(directions.isEnabled, "Directions must never be disabled by the permanently-closed badge (PRD req 4 bullet 6) — it renders on a closed place's row/modal but never blocks the route action")
    }

    // MARK: - Three dismissal paths (TRD §4.5 / §9 row 8 "manual")

    func testDismissViaCloseButtonReturnsToListlessMap() {
        app.buttons["Places"].tap()
        XCTAssertTrue(app.buttons[closedRowLabel].waitForExistence(timeout: 5))

        app.buttons["Close"].tap()

        XCTAssertFalse(app.buttons[closedRowLabel].waitForExistence(timeout: 2), "✕ close button did not dismiss the Places list")
        XCTAssertTrue(app.maps.firstMatch.exists, "Map should still be present after dismissing the list")
    }

    func testDismissViaScrimTapReturnsToListlessMap() {
        app.buttons["Places"].tap()
        XCTAssertTrue(app.buttons[closedRowLabel].waitForExistence(timeout: 5))

        // The card is bottom-anchored (`PlacesListOverlay`'s `ZStack(alignment:
        // .bottom)`); the scrim spans the full screen underneath it, so a tap
        // near the top is a scrim tap, never the card.
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()

        XCTAssertFalse(app.buttons[closedRowLabel].waitForExistence(timeout: 2), "Scrim tap did not dismiss the Places list")
        XCTAssertTrue(app.maps.firstMatch.exists)
    }

    func testDismissViaDragReturnsToListlessMap() {
        app.buttons["Places"].tap()
        XCTAssertTrue(app.buttons[closedRowLabel].waitForExistence(timeout: 5))

        // A downward drag anchored on the header text (guarantees the start
        // point is genuinely on the card, not a guess at window-relative
        // coordinates — and not on a row `Button`, whose own tap gesture
        // could otherwise compete with the card's `DragGesture`) past the
        // 80pt threshold (`PlacesListOverlay.dismissDragThreshold`). Longer
        // press duration than a plain tap so XCUITest synthesizes genuine
        // intermediate touchesMoved events for SwiftUI's `DragGesture` to
        // track, not a single jump.
        let start = app.staticTexts["Places"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.3, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

        XCTAssertFalse(app.buttons[closedRowLabel].waitForExistence(timeout: 2), "Drag past the dismiss threshold did not close the Places list")
        XCTAssertTrue(app.maps.firstMatch.exists)
    }

    // MARK: - D8 co-presentation guard, live (TRD §4.6/§9 row 8b/8c)

    /// T-078/`PAS-60` reopened: `HeatButton` is deleted — the Hour slider
    /// now lives inside `SearchOverlay`'s "Hour" segment, reached via
    /// `SearchButton`. `.search`/`.places` is still a `NavSurface`/system
    /// presentation pair, so this remains a live D8 co-presentation check.
    func testOpeningPlacesWhileSearchHourOpenReplacesItWithPlaces() {
        app.buttons["Search"].tap()
        app.buttons["Hour"].tap()
        XCTAssertTrue(app.sliders["hourSlider"].waitForExistence(timeout: 5), "Hour segment never opened")

        app.buttons["Places"].tap()

        XCTAssertTrue(app.buttons[closedRowLabel].waitForExistence(timeout: 5), "Places list never opened over an already-presented Search/Hour surface")
        XCTAssertFalse(app.sliders["hourSlider"].exists, "D8: a NavSurface and a system-level presentation must never co-present — SearchOverlay should have closed when Places opened, not stacked underneath")
    }

    /// NOTE (QA finding, non-blocking, filed below in the worklog): a raw
    /// `app.buttons["Search"].tap()` while a place-detail modal is stacked
    /// over the list is NOT physically reachable — confirmed via the
    /// xcresult accessibility snapshot of the failed first version of this
    /// test: the depth-1 `.sheet` at `.medium` occupies `{{8, 415}, {386,
    /// 451}}` (y 415-866), and `MapNavRow`'s buttons sit at y 700-744,
    /// entirely inside that span. `.presentationBackgroundInteraction`
    /// keeps the *state* reachable (no dimming/disabling), but a tap at a
    /// point the sheet's own opaque content visually covers still hits the
    /// sheet, not what is structurally "underneath" it — this pre-dates
    /// T-036/PAS-42 (the same geometry held for the original bucket-2
    /// `padding(.bottom, 32)` position) and is not a regression this task
    /// introduced. The real, reachable path is what a finger actually can
    /// do: dismiss the stacked modal first (its own ✕, reachable since it's
    /// inside the visible sheet), which lands back on the bare list with
    /// the nav row now genuinely on top of it (not a system sheet) — then
    /// switch surfaces from there. This test exercises exactly that path,
    /// which is what §9 row 8(c)'s "manual" layer can actually confirm live.
    func testDismissingStackedPlaceModalRevealsListThenLeavingPlacesOpensSearch() {
        app.buttons["Places"].tap()
        let closedRow = app.buttons[closedRowLabel]
        XCTAssertTrue(closedRow.waitForExistence(timeout: 5))
        closedRow.tap()

        XCTAssertTrue(app.staticTexts["placeDetailTitle"].waitForExistence(timeout: 5), "Place-detail modal never opened, stacked over the list")

        // Two "Close" buttons exist right now (the list's own, and the
        // modal's, stacked on top of it) — `app.buttons["Close"]` is
        // ambiguous. `isHittable` isn't a reliable disambiguator here (it's
        // an accessibility-tree check, not a literal render-occlusion
        // check, so it reported both as hittable despite the sheet visually
        // covering the list's). The modal's close button is the visually
        // topmost one, which prints last in `debugDescription`'s
        // depth-first traversal (confirmed against the xcresult
        // accessibility snapshot), so `.element(boundBy:)` on the highest
        // index is the modal's.
        let closeButtons = app.buttons.matching(NSPredicate(format: "label == 'Close'"))
        XCTAssertGreaterThanOrEqual(closeButtons.count, 1, "No \"Close\" button found")
        closeButtons.element(boundBy: closeButtons.count - 1).tap()

        XCTAssertFalse(app.staticTexts["placeDetailTitle"].waitForExistence(timeout: 2), "Place-detail modal did not dismiss via its own close button")
        XCTAssertTrue(closedRow.waitForExistence(timeout: 5), "Dismissing the stacked place modal should reveal the list unchanged underneath (TRD §5) — the same row should still be there")

        app.buttons["Search"].tap()

        XCTAssertTrue(app.staticTexts["Search"].waitForExistence(timeout: 5), "SearchOverlay never opened when switching away from a bare (unstacked) Places list")
        XCTAssertFalse(closedRow.exists, "D8: leaving .places must close the list, not leave it presented underneath Search")
    }
}
