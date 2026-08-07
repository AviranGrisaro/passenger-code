import XCTest

/// T-032 F1 regression (2026-08-03 acceptance REJECT → rebuild). TRD §2.3
/// z5: `HeatModalCard` must be "anchored a fixed distance above the nav
/// row… never `bottom: 0`" — the shipped build violated this, and the
/// violation was invisible to `HeatButtonInteractionTests`'s
/// `XCUIElement.exists` checks, since an occluded element still "exists".
/// This test reads real rendered frames instead, the same technique
/// `SearchAccessibilityTests` already uses for its 44pt checks, so a future
/// regression fails here rather than needing another live `product` render
/// pass to catch.
final class HeatModalCardLayoutTests: XCTestCase {
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

    /// Reproduces product's exact rejection scenario: +12h from a late-hour
    /// "now" crosses into the next day, so the readout carries the "next
    /// day" flag that the occlusion bug truncated to "…t day".
    func testReadoutNeverIntersectsTheNavRowAtDefaultTextSize() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        let heatButton = app.buttons["Heat"]
        XCTAssertTrue(heatButton.waitForExistence(timeout: 5), "HeatButton never appeared")
        heatButton.tap()

        let slider = app.sliders["hourSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "hourSlider never rendered")
        slider.adjust(toNormalizedSliderPosition: 1.0)

        // `.accessibilityElement(children: .combine)` surfaces this row as
        // a single `.staticText` element (confirmed against the live
        // accessibility tree, not assumed) — the combined VoiceOver label,
        // not the individual offset/clock/pill children.
        let readout = app.staticTexts["hourReadout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 5), "hourReadout never rendered")

        // Positive control (PAS-51 finding 3, TRD §9 row 5b standing rule
        // 2 — "every negative-existence check needs a positive control").
        // The frame-intersection checks below are worthless if `readout`
        // rendered empty or with the wrong content: an empty label still
        // has a frame, and a non-intersection claim about nothing proves
        // nothing. `slider.adjust(toNormalizedSliderPosition: 1.0)` above
        // is +12h, which — same as `HourFormat`'s own "next day" case —
        // crosses into the next day whenever `now`'s local hour is at or
        // past roughly noon; this control only requires the offset token,
        // which is present at every offset, not the day-dependent pill.
        XCTAssertTrue(
            readout.label.contains("+12h"),
            "hourReadout rendered but its label \"\(readout.label)\" is missing the expected \"+12h\" offset token — the frame-intersection checks below would pass vacuously against an empty or wrong label"
        )

        // The nav row stays hit-testable and on screen the whole time
        // (TRD §2.3 z7) — that is the entire premise a frame-intersection
        // check rests on.
        for label in ["Heat", "Search", "Profile"] {
            let navButton = app.buttons[label]
            XCTAssertTrue(navButton.exists, "\(label) button not in the nav row while the modal is open")
            XCTAssertFalse(
                readout.frame.intersects(navButton.frame),
                "hourReadout \(readout.frame) overlaps the \(label) nav button \(navButton.frame) — F1 regression"
            )
        }
    }

    /// TRD §9 row 5b (iii): "`HeatModalCard.frame.maxY` is strictly less
    /// than the safe-area bottom — `bottom: 0` is what §2.3 forbids by
    /// name, so it is falsified directly rather than inferred from the
    /// gap." Neither this file nor `HeatModalCardLayoutGuardTests` checked
    /// the card's own frame before PAS-51 finding 5 (`qa`, 2026-08-07) —
    /// the only existing check was a source-string match on the padding
    /// constant, which proves the *input* to layout, not what the two
    /// views' frames actually did.
    func testCardBottomEdgeClearsTheSafeAreaAtDefaultTextSize() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        let heatButton = app.buttons["Heat"]
        XCTAssertTrue(heatButton.waitForExistence(timeout: 5), "HeatButton never appeared")
        heatButton.tap()

        let card = app.otherElements["heatModalCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "heatModalCard never rendered")
        XCTAssertGreaterThan(card.frame.height, 0, "heatModalCard rendered with a zero-height frame — the maxY check below would be meaningless")

        // XCUITest exposes no direct `safeAreaInsets` accessor for a
        // rendered element, so the safe-area bottom is derived the same
        // way `EdgeGeometry`'s own D8 constants are: the full window frame
        // (== `UIScreen.main.bounds`, in points) minus the 34pt
        // home-indicator inset shared by every current notched-iPhone
        // simulator this suite runs on. That is a real runtime frame
        // comparison against a documented device constant, not a second
        // string match on the padding value.
        let windowFrame = app.windows.firstMatch.frame
        let safeAreaBottom = windowFrame.maxY - 34
        XCTAssertLessThan(
            card.frame.maxY,
            safeAreaBottom,
            "heatModalCard's bottom edge \(card.frame.maxY) reaches or passes the safe-area bottom \(safeAreaBottom) — TRD §2.3 forbids `bottom: 0`, and this is that check run directly rather than inferred from the gap constant"
        )
    }
}
