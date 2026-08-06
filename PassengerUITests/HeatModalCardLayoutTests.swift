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
}
