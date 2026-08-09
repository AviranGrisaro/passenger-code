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

        // Plain "Search" again as of T-081/`PAS-76` — `PAS-75`'s "Search
        // and hours" rename existed only to disambiguate from
        // `SearchOverlay`'s own Search/Hour segmented control, which is now
        // deleted along with the Hour segment. See `SearchButton`'s doc
        // comment.
        let searchButton = app.buttons["Search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "SearchButton never appeared in MapNavRow")
        searchButton.tap()

        let fieldLabel = app.staticTexts["Search"]
        XCTAssertTrue(fieldLabel.waitForExistence(timeout: 5), "SearchOverlay never rendered — field label missing")
    }

    /// `PAS-78` fold-in: `SearchOverlay`'s bottom-safe-area fix
    /// (`.ignoresSafeArea(.container, edges: .bottom)` instead of the
    /// unscoped default) changed the fractional geometry a result row's
    /// `.frame(minHeight: 44)` gets proposed by one more nested
    /// keyboard-aware layout pass, and the accumulated `CGFloat` rounding
    /// now lands a hair under 44 (`43.99999999999994`, live-measured, a
    /// ~6e-14pt difference — display-scale rounding noise, not a real
    /// sub-44pt row). A strict `>= 44` comparison is the wrong tool for a
    /// value that went through several `CGFloat` divisions; `epsilon` gives
    /// it the same tolerance any floating-point comparison needs, several
    /// orders of magnitude below anything a real device could render as a
    /// visible difference.
    private static let epsilon: CGFloat = 0.01

    private func meetsMinimumTarget(_ element: XCUIElement, _ context: String) {
        XCTAssertTrue(element.exists, "\(context) does not exist")
        XCTAssertGreaterThanOrEqual(element.frame.width + Self.epsilon, 44, "\(context) width below 44pt: \(element.frame)")
        XCTAssertGreaterThanOrEqual(element.frame.height + Self.epsilon, 44, "\(context) height below 44pt: \(element.frame)")
    }

    // MARK: - Dismiss via Close button (T-099/`PAS-99`, replaces T-087/`PAS-85`)
    //
    // `T-081`/`PAS-76` deleted `SearchHourSegmentInteractionTests.swift`
    // along with `SearchOverlay`'s Hour segment — that file happened to be
    // the only UI-level coverage for "tap the nav-row Search button again
    // while the overlay is open → it closes" (`MapChromeState.toggle`'s
    // exclusivity rule, unit-tested at
    // `MapChromeStateTests.toggleOnOpenSurfaceCloses()`, and confirmed
    // working live during `T-081`'s own `ios-code-reviewer`/`qa` passes).
    // T-087/`PAS-85` restored permanent UI-level coverage for that path by
    // re-tapping the nav-row `SearchButton` while the overlay was open.
    //
    // **T-099/`PAS-99` (2026-08-09) removes that path entirely:** `MapNavRow`
    // is now hidden while any `NavSurface` is presented (see `MapNavRow`'s
    // header comment), so `app.buttons["Search"]` does not exist once the
    // overlay is open — there is nothing left to re-tap. The exclusivity
    // rule this used to prove stays covered at the state level regardless
    // (`MapChromeStateTests.toggleOnOpenSurfaceCloses()`); what needs live
    // UI coverage now is the dismiss path that actually survives this
    // change — `SearchOverlay`'s own "Close" button, always reachable
    // whether or not the nav row is visible.
    func testTappingCloseButtonDismissesTheOverlay() {
        openSearch()

        app.buttons["Close"].tap()

        XCTAssertFalse(
            app.staticTexts["Search"].waitForExistence(timeout: 2),
            "SearchOverlay stayed open (field label still rendered) after tapping its Close button"
        )
        XCTAssertFalse(app.otherElements["searchOverlayCard"].exists, "searchOverlayCard still in the tree after tapping Close")
        XCTAssertTrue(app.maps.firstMatch.exists, "Map should still be present after the overlay closes")
    }

    // MARK: - Nav row hidden while presented (T-099/`PAS-99`)

    /// While `SearchOverlay` is open, all 3 of `MapNavRow`'s buttons — not
    /// just the one that opened it — must be gone from the accessibility
    /// tree entirely, along with the row's own `mapNavRow` container
    /// element (`.accessibilityElement(children: .contain)` in
    /// `MapNavRow.swift`). Restored the instant the overlay's own Close
    /// button dismisses it.
    ///
    /// **`PAS-97` (merged into `PAS-99`): the surviving dismiss path must be
    /// reachable and correctly labeled under VoiceOver/Switch Control, not
    /// just by touch.** `app.buttons["Close"]` resolves through the same
    /// `UIAccessibility` tree both technologies read, so its existence and
    /// exact `.label` here are live proof of both — not source-reading. See
    /// `MapNavRow`'s header comment for the full reasoning, including the
    /// disclosed limitation (no simulator API to drive a literal Switch
    /// Control scan or VoiceOver announcement).
    func testNavRowIsHiddenWhileSearchOverlayIsOpenAndReappearsOnDismiss() {
        openSearch()

        XCTAssertFalse(app.buttons["Search"].exists, "Search button still in the tree while SearchOverlay is open")
        XCTAssertFalse(app.buttons["Places"].exists, "Places button still in the tree while SearchOverlay is open")
        XCTAssertFalse(app.buttons["Profile"].exists, "Profile button still in the tree while SearchOverlay is open")
        XCTAssertFalse(app.otherElements["mapNavRow"].exists, "mapNavRow container still in the tree while SearchOverlay is open")

        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists, "Close button not reachable via the accessibility tree while SearchOverlay is open")
        XCTAssertEqual(closeButton.label, "Close", "Close button's VoiceOver/Switch Control label is wrong")
        closeButton.tap()

        XCTAssertTrue(app.buttons["Search"].waitForExistence(timeout: 5), "Search button did not reappear after dismissing SearchOverlay")
        XCTAssertTrue(app.buttons["Places"].exists, "Places button did not reappear after dismissing SearchOverlay")
        XCTAssertTrue(app.buttons["Profile"].exists, "Profile button did not reappear after dismissing SearchOverlay")
    }

    // MARK: - §9 row 8(a): 44pt frames

    func testSearchButtonAndChipsMeetMinimumTouchTarget() {
        // Measured before opening the overlay, not via `openSearch()` —
        // T-099/`PAS-99` hides `SearchButton` once the overlay is open, so
        // its own touch target can only be measured while it's still on
        // screen. The chip row, measured after, is unaffected either way.
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        // Plain "Search" again as of T-081/`PAS-76` — `SearchOverlay`'s own
        // Search/Hour segmented control (the thing "Search and hours" used
        // to disambiguate from, per `PAS-75`) is deleted along with the
        // Hour segment, so a direct lookup is unambiguous.
        let searchButton = app.buttons["Search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "SearchButton never appeared in MapNavRow")
        meetsMinimumTarget(searchButton, "SearchButton")
        searchButton.tap()

        let fieldLabel = app.staticTexts["Search"]
        XCTAssertTrue(fieldLabel.waitForExistence(timeout: 5), "SearchOverlay never rendered — field label missing")
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
