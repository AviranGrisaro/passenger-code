import XCTest

/// TRD §4.7, §9 row 2b: measures the `HourRepaint` `os_signpost` interval
/// directly — "`selectedHour` written → every Hood's band resolved for the
/// new hour" — the same construction as `ColdOpenPerformanceTests` uses for
/// `ColdOpenToInteractive`, and for the identical reason: this is a named,
/// specific milestone, not the generic thing a launch/render metric would
/// measure. Budget: <400ms (TRD §4.7's own structural-first, measured-
/// second posture — no code path fetches on an hour change, so the budget
/// is held before it is ever measured).
///
/// **Simulator run only, in this build environment** — same caveat
/// `ColdOpenPerformanceTests` states for its own on-device requirement.
final class HeatRepaintPerformanceTests: XCTestCase {
    func testHourRepaintSignpost() {
        let app = XCUIApplication()
        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(
            metrics: [XCTOSSignpostMetric(subsystem: "com.avirangrisaro.passenger", category: "HeatRepaint", name: "HourRepaint")]
        ) {
            app.launch()

            let heatButton = app.buttons["Heat"]
            XCTAssertTrue(heatButton.waitForExistence(timeout: 5), "HeatButton never appeared")
            heatButton.tap()

            let slider = app.sliders["hourSlider"]
            XCTAssertTrue(slider.waitForExistence(timeout: 5), "hourSlider never rendered")
            // Each `adjust` is a real hour change from the control's
            // current position, firing `HeatRepaintSignpost.begin()` /
            // `endIfPending()` around `HeatComposition.fills(...)`.
            slider.adjust(toNormalizedSliderPosition: 0.5)
            slider.adjust(toNormalizedSliderPosition: 1.0)

            app.terminate()
        }
    }
}
