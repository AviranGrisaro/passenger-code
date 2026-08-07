import UIKit
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
/// positive content control on the readout label. **Re-derived at C16
/// (T-077/`PAS-51`, TRD v6), not carried over 1:1:** the AX3/AX5 rendered
/// dynamic-type-ceiling suite this file's header used to disclose as an
/// owed follow-up. `HeatModalCardDynamicTypeCeilingTests` queried
/// `heatModalCard`'s own frame against a card whose height grew with its
/// content; `SearchOverlay`'s card is a fixed screen fraction instead
/// (§9 row 5b's v6 rewrite), so every observable below moved off the card
/// frame onto its content elements (`hourReadout`, `hourSlider`) plus
/// *containment within* `hourSegmentCard` (C16's new identifier) — see
/// `testHourSegmentContentStaysUnoccludedAndContainedAcrossTextSizes()`
/// and `testHourSegmentDynamicTypeCeilingBindsAtAX5()` below.
/// `SearchOverlayHourGuardTests` (`PassengerTests/`) keeps the
/// source-level ceiling-constant guard as a regression backstop only — it
/// does not discharge TRD §9 row 5b, which is why the checks below exist.
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
        driveSliderToMaximum(slider)

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

    /// `slider.adjust(toNormalizedSliderPosition: 1.0)` is not perfectly
    /// deterministic on this discrete-stepped `Slider` — XCUITest computes
    /// the target touch point from the track's normalized width, and that
    /// math occasionally lands one step short of the true maximum (found
    /// live at C16, T-077/`PAS-51`: `testReadoutNeverIntersectsThe
    /// NavRowAtDefaultTextSize` intermittently read "+11 hours" instead of
    /// "+12 hours" off a single `adjust` call). Row 5b's positive control
    /// assumes the maximum stop is reached exactly, not approximately, so
    /// this retries a few times, reading the slider's own accessibility
    /// value back, until "+12 hours" is confirmed.
    private func driveSliderToMaximum(_ slider: XCUIElement) {
        for _ in 0..<5 {
            slider.adjust(toNormalizedSliderPosition: 1.0)
            let value = (slider.value as? String) ?? ""
            if value.contains("+12 hours") {
                return
            }
        }
    }

    // MARK: - C16 (TRD §9 row 5b/6(c), T-077/`PAS-51`) — rendered AX3/AX5 suite

    /// One rendered capture: the four elements row 5b measures, plus the
    /// window frame (for the "fully inside the window" containment half)
    /// and the readout's accessibility label (the positive control). All
    /// values are copied out of the live `XCUIElement`s before the app that
    /// produced them terminates, so a capture stays valid after its own
    /// launch is torn down.
    private struct HourSegmentCapture {
        let card: CGRect
        let navRow: CGRect
        let readout: CGRect
        let slider: CGRect
        let windowFrame: CGRect
        let readoutLabel: String
    }

    /// One fixed instant, derived from the **host's** own `Calendar
    /// .current` — the same calendar `HourFormat.readout` compares against
    /// inside the app (`MapScreen.swift:185`, `calendar: .current`), so
    /// this stays correct regardless of which timezone the runner is in.
    /// `localHour` defaults to 22:00 today: `anchorHour` floors to that
    /// hour, and the slider's maximum stop (+12h) lands at 10:00 the
    /// *following* calendar day, so `HourFormat.isNextDay` is `true` at
    /// every run — never dependent on what wall-clock hour the suite
    /// happens to execute at (TRD §9 row 5b, finding 4).
    private func fixedNowArgument(localHour: Int = 22) -> String {
        let calendar = Calendar.current
        let pinned = calendar.date(bySettingHour: localHour, minute: 0, second: 0, of: Date()) ?? Date()
        return ISO8601DateFormatter().string(from: pinned)
    }

    /// Launches (or relaunches, if `app` is already running from a prior
    /// capture in the same test) with the given launch arguments, opens the
    /// Hour segment, drives the slider to its maximum stop (+12h — the same
    /// stop F1 originally truncated at, and row 5b(c)'s positive control
    /// needs `isNextDay == true`), and records all four elements' rendered
    /// frames plus the readout's label. Terminates the app before
    /// returning so the next capture in the same test starts from a clean
    /// process.
    private func captureHourSegment(launchArguments: [String]) -> HourSegmentCapture {
        app.launchArguments = launchArguments
        openHourSegment()

        let slider = app.sliders["hourSlider"]
        driveSliderToMaximum(slider)

        let card = app.otherElements["hourSegmentCard"]
        let navRow = app.otherElements["mapNavRow"]
        let readout = app.staticTexts["hourReadout"]

        XCTAssertTrue(card.waitForExistence(timeout: 5), "hourSegmentCard never rendered (\(launchArguments))")
        XCTAssertTrue(navRow.waitForExistence(timeout: 5), "mapNavRow never rendered (\(launchArguments))")
        XCTAssertTrue(readout.waitForExistence(timeout: 5), "hourReadout never rendered (\(launchArguments))")
        XCTAssertTrue(slider.exists, "hourSlider never rendered (\(launchArguments))")

        // "Counts and non-emptiness first" (§9 standing rule) — a frame
        // that never rendered would satisfy every containment and
        // non-intersection claim below for free, which is the exact way
        // this row could pass while the requirement fails.
        for (name, frame) in [
            ("hourSegmentCard", card.frame), ("mapNavRow", navRow.frame),
            ("hourReadout", readout.frame), ("hourSlider", slider.frame),
        ] {
            XCTAssertGreaterThan(frame.width, 0, "\(name) rendered with zero width (\(launchArguments)) — row is unrun, not passed")
            XCTAssertGreaterThan(frame.height, 0, "\(name) rendered with zero height (\(launchArguments)) — row is unrun, not passed")
        }

        let capture = HourSegmentCapture(
            card: card.frame, navRow: navRow.frame, readout: readout.frame,
            slider: slider.frame, windowFrame: app.windows.firstMatch.frame,
            readoutLabel: readout.label
        )
        app.terminate()
        return capture
    }

    /// Row 5b(i)–(iii) plus the positive control, run against one capture —
    /// the row requires these "in captures (a) and (b) independently", so
    /// both call sites use this same body rather than duplicating it.
    private func assertHourSegmentCapture(_ capture: HourSegmentCapture, label: String) {
        // (i) occlusion, restated on the content [v6] — never on the card,
        // which is deliberately flush against the true bottom edge with
        // `MapNavRow` drawn above it by z-order; a card-vs-navRow
        // non-intersection claim would fail a correct build.
        XCTAssertFalse(
            capture.readout.intersects(capture.navRow),
            "[\(label)] hourReadout \(capture.readout) overlaps mapNavRow \(capture.navRow) — F1-class regression"
        )
        XCTAssertFalse(
            capture.slider.intersects(capture.navRow),
            "[\(label)] hourSlider \(capture.slider) overlaps mapNavRow \(capture.navRow)"
        )

        // (ii) containment [v6] — the failure mode this merge introduced:
        // `hourContent` has no `.clipped()`, so growth at AX3 can push
        // `hourSlider` toward and past the card's own bottom edge, which is
        // also the screen's bottom edge.
        XCTAssertTrue(
            capture.card.contains(capture.readout),
            "[\(label)] hourSegmentCard \(capture.card) does not contain hourReadout \(capture.readout)"
        )
        XCTAssertTrue(
            capture.card.contains(capture.slider),
            "[\(label)] hourSegmentCard \(capture.card) does not contain hourSlider \(capture.slider) — the P0 ≥44pt control may be off-screen"
        )
        XCTAssertTrue(
            capture.windowFrame.contains(capture.readout),
            "[\(label)] hourReadout \(capture.readout) falls outside the window frame \(capture.windowFrame)"
        )
        XCTAssertTrue(
            capture.windowFrame.contains(capture.slider),
            "[\(label)] hourSlider \(capture.slider) falls outside the window frame \(capture.windowFrame)"
        )

        // (iii) the P0 control is still a control at this capture's text
        // size — req 6(b)'s ≥44pt stops being proved by the frame constant
        // alone once the container stopped growing with content [v6].
        XCTAssertGreaterThanOrEqual(
            capture.slider.height, 44,
            "[\(label)] hourSlider height \(capture.slider.height)pt is below the 44pt P0 minimum"
        )

        // Positive control (§9 standing rule 2, corrected at v6): the real
        // VoiceOver phrase `HourFormat.voiceOverValue` assembles — never
        // the visual "+12h" short form, which `.accessibilityLabel`'s
        // override means XCUITest never reads.
        XCTAssertTrue(
            capture.readoutLabel.contains("+12 hours"),
            "[\(label)] hourReadout.label \"\(capture.readoutLabel)\" is missing \"+12 hours\" — the row is unrun, not passed"
        )
        XCTAssertTrue(
            capture.readoutLabel.contains("next day"),
            "[\(label)] hourReadout.label \"\(capture.readoutLabel)\" is missing \"next day\" — the row is unrun, not passed"
        )
    }

    /// Row 5b(a)/(b) and 6(c): default text size and the Hour segment's own
    /// Dynamic Type ceiling (`.accessibility3`, `SearchOverlay
    /// .maxDynamicTypeSize`), driven by C15's `-uiTestDynamicTypeSize`
    /// launch argument rather than either dead simulator mechanism
    /// (`passenger-code/CLAUDE.md`'s Simulator facts). Each capture is
    /// checked independently against 5b(i)–(iii) plus the positive
    /// control, then the readout's wrap check runs across both — this is
    /// F2's regression, restated for `HourReadout`'s combined accessibility
    /// element (`HourReadout.swift:29-34`): since the pill/numeral/clock
    /// have no individually queryable frames, one line of growth is
    /// checked on the combined row's height instead.
    func testHourSegmentContentStaysUnoccludedAndContainedAcrossTextSizes() {
        let now = fixedNowArgument()

        let defaultCapture = captureHourSegment(launchArguments: ["-uiTestNow", now])
        assertHourSegmentCapture(defaultCapture, label: "default")

        let ax3Capture = captureHourSegment(launchArguments: ["-uiTestNow", now, "-uiTestDynamicTypeSize", "accessibility3"])
        assertHourSegmentCapture(ax3Capture, label: "AX3")

        // Wrap check [v5, restated for the combined element at v6]:
        // `hourReadout.frame.height` at AX3 stays under twice its default
        // height, scaled by the AX3/default text-size ratio — i.e. it
        // still occupies one line rather than wrapping. The ratio comes
        // from `UIFont`'s own preferred body size at each content size
        // category, not a hardcoded constant, so this tracks Apple's own
        // scale curve rather than one snapshot of it.
        let scaleRatio = Self.ax3OverDefaultTextScaleRatio()
        let oneLineCeiling = 2 * defaultCapture.readout.height * scaleRatio
        XCTAssertLessThan(
            ax3Capture.readout.height, oneLineCeiling,
            "hourReadout grew to \(ax3Capture.readout.height)pt at AX3 (default \(defaultCapture.readout.height)pt × \(scaleRatio) scale ratio → \(oneLineCeiling)pt ceiling) — no longer one line, the F2 wrap regression"
        )
    }

    /// Row 5b(b2)/6(c): a third capture requested at **AX5**, one step past
    /// the Hour segment's own `.accessibility3` ceiling. If the clamp
    /// binds, AX5's rendered `hourReadout`/`hourSlider` frames are
    /// identical to AX3's — that equality *is* the ceiling holding, and is
    /// the only claim about AX5 this design permits (§9 row 5b, v5/v6). A
    /// mismatch here means C15's `.environment(\.dynamicTypeSize, …)`
    /// override did not propagate as the composition root's own
    /// `[ASSUMPTION]` requires, and per the row's own instruction that is a
    /// **BLOCKED** disclosure, never a fall back to the source grep.
    func testHourSegmentDynamicTypeCeilingBindsAtAX5() {
        let now = fixedNowArgument()

        let ax3Capture = captureHourSegment(launchArguments: ["-uiTestNow", now, "-uiTestDynamicTypeSize", "accessibility3"])
        let ax5Capture = captureHourSegment(launchArguments: ["-uiTestNow", now, "-uiTestDynamicTypeSize", "accessibility5"])

        XCTAssertEqual(
            ax5Capture.readout.width, ax3Capture.readout.width, accuracy: 0.5,
            "hourReadout width at AX5 (\(ax5Capture.readout)) differs from AX3 (\(ax3Capture.readout)) — the .accessibility3 ceiling did not bind. BLOCKED per TRD §9 row 5b, not a source-grep fallback."
        )
        XCTAssertEqual(
            ax5Capture.readout.height, ax3Capture.readout.height, accuracy: 0.5,
            "hourReadout height at AX5 (\(ax5Capture.readout)) differs from AX3 (\(ax3Capture.readout)) — the .accessibility3 ceiling did not bind. BLOCKED per TRD §9 row 5b, not a source-grep fallback."
        )
        XCTAssertEqual(
            ax5Capture.slider.height, ax3Capture.slider.height, accuracy: 0.5,
            "hourSlider height at AX5 (\(ax5Capture.slider)) differs from AX3 (\(ax3Capture.slider)) — the .accessibility3 ceiling did not bind. BLOCKED per TRD §9 row 5b, not a source-grep fallback."
        )
    }

    /// The AX3/default text-size ratio the wrap check above scales by, read
    /// off `UIFont`'s own preferred body size at each content size category
    /// rather than a hardcoded constant (`DynamicTypeSize.accessibility3`
    /// ≙ `UIContentSizeCategory.accessibilityExtraLarge`; the OS default
    /// text size ≙ `.large`).
    private static func ax3OverDefaultTextScaleRatio() -> CGFloat {
        func bodyPointSize(_ category: UIContentSizeCategory) -> CGFloat {
            let trait = UITraitCollection(preferredContentSizeCategory: category)
            return UIFont.preferredFont(forTextStyle: .body, compatibleWith: trait).pointSize
        }
        return bodyPointSize(.accessibilityExtraLarge) / bodyPointSize(.large)
    }
}
