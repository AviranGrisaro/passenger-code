import XCTest

/// search-quick-filters TRD §9 row 8, §11 C13 — the "real UI-level
/// accessibility tests" `ios-code-reviewer` flagged as specified but not
/// shipped (2026-08-03, APPROVE WITH MINORS, item 8): 44pt frames, exact
/// VoiceOver strings, Dynamic Type growth. Every new test file the build
/// shipped (`SearchIndexTests`, `SearchQueryTests`, …) is pure-logic Swift
/// Testing with no simulator — this is the UI-level half those cannot cover
/// (a `Button`'s live rendered frame, or a real accessibility tree walk, both
/// need a running app). Closed by `qa` at the T-038/PAS-29 QA pass, same
/// construction as `ProfileButtonInteractionTests`/`DetailSheetInteractionTests`.
///
/// Fixture data is the shipped seed (`Passenger/Resources/places-tel-aviv.json`,
/// `hoods-tel-aviv.json`), not a mock — "Anna Loulou Bar" (category
/// `eat-drink`, Hood `florentin`) and the Hood "Florentin" are real rows,
/// confirmed by direct read before writing this file, and are the same two
/// examples TRD §4.8/§9 row 8(b) pins by name.
final class SearchAccessibilityTests: XCTestCase {
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

    /// Opens the search overlay and returns once the field's visible label
    /// (TRD §9 row 2e/2f — a static "Search" label distinct from the
    /// `TextField`'s own prompt) has appeared, proving the overlay is live.
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

    private func meetsMinimumTarget(_ element: XCUIElement, _ context: String) {
        XCTAssertTrue(element.exists, "\(context) does not exist")
        XCTAssertGreaterThanOrEqual(element.frame.width, 44, "\(context) width below 44pt: \(element.frame)")
        XCTAssertGreaterThanOrEqual(element.frame.height, 44, "\(context) height below 44pt: \(element.frame)")
    }

    // MARK: - §9 row 8(a): 44pt frames

    func testSearchButtonAndChipsMeetMinimumTouchTarget() {
        openSearch()

        // T-078/`PAS-60` reopened: `SearchOverlay`'s own Search/Hour
        // segmented control also renders a "Search"-labeled element once
        // the overlay is open, making `app.buttons["Search"]` ambiguous —
        // the nav-row button is the one that renders last in the
        // accessibility tree (same disambiguation pattern
        // `PlacesListInteractionTests` already uses for its two "Close"
        // buttons).
        let searchButtons = app.buttons.matching(NSPredicate(format: "label == 'Search'"))
        XCTAssertGreaterThanOrEqual(searchButtons.count, 1, "No \"Search\" button found")
        meetsMinimumTarget(searchButtons.element(boundBy: searchButtons.count - 1), "SearchButton")
        meetsMinimumTarget(app.buttons["Eat & Drink"], "Eat & Drink chip")
        meetsMinimumTarget(app.buttons["Things to do"], "Things to do chip")
    }

    func testResultRowMeetsMinimumTouchTarget() {
        openSearch()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Florentin")

        // The row is one merged accessibility element (§4.8:
        // `.accessibilityElement(children: .ignore)`), reachable by its
        // pinned VoiceOver label — same lookup-by-label convention this
        // codebase already uses for `SearchButton`/`ProfileButton`, which
        // carry no explicit identifier either.
        let hoodRow = app.buttons["Florentin, Hood"]
        XCTAssertTrue(hoodRow.waitForExistence(timeout: 5), "Hood result row for \"Florentin\" never appeared")
        meetsMinimumTarget(hoodRow, "Florentin Hood result row")
    }

    // MARK: - §9 row 8(b): VoiceOver labels pinned exactly (TRD §4.8)

    func testHoodResultVoiceOverLabelIsPinnedExactly() {
        openSearch()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Florentin")

        let hoodRow = app.buttons["Florentin, Hood"]
        XCTAssertTrue(hoodRow.waitForExistence(timeout: 5), "expected a row whose VoiceOver label is exactly \"Florentin, Hood\"")
        XCTAssertEqual(hoodRow.label, "Florentin, Hood")
    }

    func testPlaceResultVoiceOverLabelIsPinnedExactly() {
        openSearch()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Anna Loulou")

        let placeRow = app.buttons["Anna Loulou Bar, place, Eat & Drink"]
        XCTAssertTrue(
            placeRow.waitForExistence(timeout: 5),
            "expected a row whose VoiceOver label is exactly \"Anna Loulou Bar, place, Eat & Drink\""
        )
        XCTAssertEqual(placeRow.label, "Anna Loulou Bar, place, Eat & Drink")
    }

    // MARK: - §9 row 8(c): Dynamic Type growth — verified structurally, not
    // via a live content-size override.
    //
    // Both standard simulator mechanisms for forcing the largest
    // accessibility content size were tried live during the T-038/PAS-29 QA
    // pass and neither took visible effect on this build's Simulator
    // runtime (Xcode 17F113 / iOS 26.5, iPhone 17e): `-UIPreferredContentSizeCategoryName
    // UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge` as a launch
    // argument, and `xcrun simctl ui <udid> content_size
    // accessibility-extra-extra-extra-large` (confirmed stored — the getter
    // echoed it back, survived an app relaunch and a full simulator
    // reboot). Neither changed rendered text size anywhere, confirmed by
    // screenshot of the plain SpringBoard home screen after the `simctl ui`
    // override and a reboot: app name labels rendered at default size, not
    // the dramatically larger accessibility-range size real iOS renders.
    // This is a simulator/tooling limitation, not a Passenger behavior —
    // asserting row growth against a content size that never actually
    // applied would be a test that fails (or passes) by environmental
    // accident, the same class of problem L-010 names for existing flakes.
    //
    // TRD §4.8's own mechanism is structural and needs no live content-size
    // override to verify: "no `.lineLimit` anywhere ... `.fixedSize(horizontal:
    // false, vertical: true)` on every text run." `SearchRowGrowthGuardTests`
    // (`PassengerTests/`) asserts that directly against the real source.
    // The two properties this file CAN verify live regardless of content
    // size — 44pt minimum frames and exact VoiceOver labels — are covered
    // above.
}
