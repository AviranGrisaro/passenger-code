import XCTest

/// T-078/`PAS-60` reopened (`nav-row-v2-redesign.md` §1) — replaces
/// `HeatButtonInteractionTests`, `HeatModalCardLayoutTests`, and
/// `HeatModalCardDynamicTypeCeilingTests`, all deleted along with the
/// standalone `HeatButton`/`HeatModalCard` they exercised. The map-hour
/// slider is now the "Hour" segment of `SearchOverlay`'s own Search/Hour
/// picker, reached through the same `SearchButton` that already opens
/// search — there is no more "Heat" button to find, and that removal is
/// deliberate, not silent breakage (`SearchButton`'s `accessibilityLabel`
/// is unchanged; `"Heat"` never had a surviving label to retarget, since
/// `HeatButton` itself is gone).
///
/// **Coverage carried over from the deleted files:** open via the real
/// button, re-tap-to-dismiss, slider-driven hour change, the F1 occlusion
/// regression (hourReadout must never intersect the nav row), and a
/// positive content control on the readout label. **Not carried over,
/// disclosed rather than silently dropped:** the full AX3/AX5 rendered
/// dynamic-type-ceiling suite `HeatModalCardDynamicTypeCeilingTests` built
/// for `PAS-51`'s TRD §9 row 5b/6(c) — that suite queried `heatModalCard`/
/// `hourReadout` identifiers against a card whose height grew with its own
/// content. `SearchOverlay`'s card is a fixed screen-fraction height
/// instead (unchanged by this merge), so the same rendered-frame method
/// doesn't carry over 1:1. `SearchOverlayHourGuardTests`
/// (`PassengerTests/`) keeps the source-level ceiling guard as a regression
/// backstop; a rendered AX3/AX5 re-derivation against `SearchOverlay` is
/// left for a follow-up story rather than invented here under this task's
/// scope.
final class SearchHourSegmentInteractionTests: XCTestCase {
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

    /// Opens `SearchOverlay` via the real `SearchButton` and switches to the
    /// Hour segment, returning once `hourSlider` is live.
    private func openHourSegment() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        // "Search and hours" — `PAS-75` renamed `SearchButton`'s label off
        // "Search" to stop colliding with `SearchOverlay`'s own "Search"
        // segment (T-079 re-fix, 2026-08-07).
        let searchButton = app.buttons["Search and hours"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "SearchButton never appeared in MapNavRow")
        searchButton.tap()

        let hourSegment = app.buttons["Hour"]
        XCTAssertTrue(hourSegment.waitForExistence(timeout: 5), "Hour segment never appeared in SearchOverlay's picker")
        hourSegment.tap()

        let slider = app.sliders["hourSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "hourSlider never rendered inside the Hour segment")
    }

    func testTappingSearchThenHourSegmentOpensTheSlider() {
        openHourSegment()
        // `openHourSegment()` already asserts `hourSlider` exists — this
        // test's own body is the positive-control assertion.
        XCTAssertTrue(app.staticTexts["hourSegmentTitle"].exists, "\"Map hour\" title never rendered in the Hour segment")
    }

    /// The nav-row `SearchButton`, disambiguated from `SearchOverlay`'s own
    /// "Search" segment (both share the label "Search" while the overlay is
    /// open) — the nav-row button renders last in the accessibility tree,
    /// same pattern `PlacesListInteractionTests` uses for its two "Close"
    /// buttons.
    private var searchNavButton: XCUIElement {
        let matches = app.buttons.matching(NSPredicate(format: "label == 'Search'"))
        return matches.element(boundBy: matches.count - 1)
    }

    func testTappingSearchAgainDismissesTheOverlayFromTheHourSegment() {
        openHourSegment()

        // Re-tapping the Search button is the toggle-closed path (TRD §4.1)
        // — carried over from `HeatButtonInteractionTests
        // .testTappingHeatButtonAgainDismissesTheModal`, retargeted here
        // per `nav-row-v2-redesign.md` §1's explicit instruction: the
        // control that owns dismiss is now `SearchButton`, since
        // `HeatButton` no longer exists.
        searchNavButton.tap()

        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.sliders["hourSlider"])
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, "SearchOverlay stayed open (on the Hour segment) after re-tapping SearchButton")
    }

    func testDraggingTheSliderMovesTheSelectedHourAndRepaintsSilently() {
        openHourSegment()

        let slider = app.sliders["hourSlider"]
        let initialValue = (slider.value as? String) ?? ""
        XCTAssertTrue(
            initialValue.hasPrefix("Now"),
            "cold launch must start the control at 'Now' (req 3), got: \(initialValue)"
        )

        slider.adjust(toNormalizedSliderPosition: 1.0)

        let valueAfterAdjust = (slider.value as? String) ?? ""
        XCTAssertFalse(
            valueAfterAdjust.hasPrefix("Now"),
            "moving the slider to its maximum must move off 'Now', got: \(valueAfterAdjust)"
        )
    }

    /// F1 regression (originally `HeatModalCardLayoutTests
    /// .testReadoutNeverIntersectsTheNavRowAtDefaultTextSize`) — the hour
    /// readout must never render underneath `MapNavRow`'s buttons at
    /// default text size.
    func testReadoutNeverIntersectsTheNavRowAtDefaultTextSize() {
        openHourSegment()

        let slider = app.sliders["hourSlider"]
        slider.adjust(toNormalizedSliderPosition: 1.0)

        let readout = app.staticTexts["hourReadout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 5), "hourReadout never rendered")

        // Positive control (same reasoning `HeatModalCardLayoutTests` used):
        // an empty label still has a frame, and a non-intersection claim
        // about nothing proves nothing. `readout.label` is the
        // accessibility label `HourFormat.voiceOverValue` assembles
        // ("+12 hours, 03:00, next day" — confirmed live, not assumed from
        // `offsetLabel`'s own "+12h" short form, which is a different,
        // visual-only string never surfaced to XCUITest once
        // `.accessibilityElement(children: .combine)` plus an explicit
        // `.accessibilityLabel` override are both in play).
        XCTAssertTrue(
            readout.label.contains("+12 hours"),
            "hourReadout rendered but its label \"\(readout.label)\" is missing the expected \"+12 hours\" offset token"
        )
        XCTAssertTrue(
            readout.label.contains("next day"),
            "hourReadout rendered but its label \"\(readout.label)\" is missing the expected \"next day\" qualifier"
        )

        // `searchNavButton` (the property above) for the nav-row button —
        // `SearchOverlay`'s own "Search" segment shares that label while
        // the overlay is open, and `readout.frame.intersects(...)` needs
        // the real nav-row button's frame, not the segmented control's.
        for (label, lookup) in [("Search", searchNavButton), ("Profile", app.buttons["Profile"]), ("Places", app.buttons["Places"])] {
            XCTAssertTrue(lookup.exists, "\(label) button not in the nav row while the Hour segment is open")
            XCTAssertFalse(
                readout.frame.intersects(lookup.frame),
                "hourReadout \(readout.frame) overlaps the \(label) nav button \(lookup.frame) — F1-class regression"
            )
        }
    }
}
