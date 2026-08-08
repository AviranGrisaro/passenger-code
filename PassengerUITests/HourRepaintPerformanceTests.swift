import XCTest

/// TRD §4.7, §9 row 2b: measures the `HourRepaint` `os_signpost` interval
/// directly — "`selectedHour` written → every Hood's band resolved for the
/// new hour" — the same construction `ColdOpenPerformanceTests` uses for
/// `ColdOpenToInteractive`, and for the identical reason: this is a named,
/// specific milestone, not the generic thing a launch/render metric would
/// measure. Budget: <400ms (TRD §4.7's own structural-first, measured-second
/// posture — no code path fetches on an hour change, so the budget is held
/// before it is ever measured). The budget figure, the `XCTOSSignpostMetric`
/// subsystem/category/name, and the 5-iteration construction are carried
/// over unchanged from the deleted original (recovered via `git show
/// b2dc981^:PassengerUITests/HourRepaintPerformanceTests.swift`, T-081/
/// `PAS-76`'s deletion commit) — only the interaction that reaches the
/// signpost changed. One correction from the original along the way: the
/// original constructed an `XCTMeasureOptions` with `iterationCount = 5` but
/// never passed it to `measure(metrics:options:)`, so it was dead code and
/// the run used XCTest's own default iteration count instead. This version
/// actually passes `options:`, matching `ColdOpenPerformanceTests`' working
/// pattern.
///
/// **T-081/`PAS-76` deleted the search modal's Hour segment entirely** —
/// `HourSlider`/`HourReadout` are gone, so the original path (tap Search →
/// tap Hour → adjust `hourSlider`) no longer exists anywhere in the app.
/// `EdgeHourZone` ("the sides", `Passenger/EdgeHour/EdgeHourZone.swift`) is
/// now the *only* hour-selection input, and it has no accessibility
/// identifier or `XCUIElement` slider affordance — it's a raw `DragGesture`
/// on a `Color.clear` capture strip. This rewrite reaches it the same way
/// `EdgeHourZoneInteractionTests` already does for the identical view (that
/// suite predates this one and is a currently-passing pattern in this same
/// target, not a new invention this ticket had to derive from scratch):
/// `map.coordinate(withNormalizedOffset:)` at a small `dx` well inside the
/// 24pt leading-edge capture zone (`EdgeGeometry.captureWidth`), driven with
/// `XCUIElement.press(forDuration:thenDragTo:)` — coordinate-space math
/// against the edge band, not an element query, per T-085/`PAS-82`'s brief.
///
/// **Reliability, disclosed honestly (T-085/`PAS-82`'s own allowance for
/// this).** `press(forDuration:thenDragTo:)` against a raw `DragGesture`
/// with no accessibility identifier on the gesture surface itself is
/// inherently more sensitive to simulator load/timing than an
/// `XCUIElement`-based interaction — an element lookup can retry via
/// `waitForExistence`, a coordinate-synthesized drag cannot. This is not a
/// new failure mode this test introduces: `EdgeHourZoneInteractionTests`
/// already carries the identical risk for the identical view, and both
/// suites lean on the same two mitigations that file already established —
/// `-uiTestExposeCameraRegion`'s `selectedHourDebugDump` seam to assert each
/// drag actually wrote a new hour (so a silent no-op drag fails loudly
/// instead of quietly reporting a meaningless signpost measurement), and the
/// location-permission interruption monitor, since a fresh-launch alert
/// covering the screen can otherwise eat the first drag's touch-down. Ran
/// green in this build environment (see PROGRESS.md's T-085 worklog entry
/// for the actual measured values), but — same as `EdgeHourZoneInteractionTests`
/// — a coordinate drag against a raw gesture surface is not as bulletproof
/// as tapping a named `XCUIElement`, and a future simulator/Xcode version
/// could change touch-synthesis timing enough to need re-tuning the
/// `press(forDuration:)` duration or the normalized offsets below.
///
/// **Simulator run only, in this build environment** — same caveat
/// `ColdOpenPerformanceTests` states for its own on-device requirement.
final class HourRepaintPerformanceTests: XCTestCase {
    private var app: XCUIApplication!

    /// Same rationale as `EdgeHourZoneInteractionTests`: well inside the
    /// 24pt capture zone on any current device width (390–430pt) — `0.02 *
    /// width` is 8–9pt, comfortably short of the 24pt boundary.
    private static let leadingEdgeX: CGFloat = 0.02

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiTestExposeCameraRegion"]

        // Same mitigation `EdgeHourZoneInteractionTests` uses: a fresh
        // simulator (or one that hasn't been granted location yet) can show
        // this alert over the map on cold launch, which would otherwise eat
        // the first measured iteration's touch-down.
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

    func testHourRepaintSignpostViaEdgeHourZoneDrag() {
        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(
            metrics: [XCTOSSignpostMetric(subsystem: "com.avirangrisaro.passenger", category: "HeatRepaint", name: "HourRepaint")],
            options: options
        ) {
            app.launch()

            let map = app.maps.firstMatch
            XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

            let hourDump = app.otherElements["selectedHourDebugDump"]
            XCTAssertTrue(hourDump.waitForExistence(timeout: 5), "selectedHour debug dump never appeared")
            let hourAtLaunch = hourDump.value as? String
            XCTAssertEqual(hourAtLaunch, "0", "cold launch must start at hour 0 ('Now')")

            // Two consecutive complete drags inside the leading edge's
            // capture band — same construction (and same reason)
            // `EdgeHourZoneInteractionTests` uses: `press(forDuration:
            // thenDragTo:)` is a single synthesized gesture that blocks
            // until it completes, so there is no mid-gesture callback to
            // fire the signpost from. Each full drag is its own real hour
            // change, mirroring the deleted original's two
            // `slider.adjust(...)` calls — and each is what actually fires
            // `HeatRepaintSignpost.begin()`/`endIfPending()` around
            // `HeatComposition.fills(...)` (`Passenger/Map/MapScreen.swift`),
            // regardless of which writer (`HourSlider`, formerly, or
            // `EdgeHourZone`, now) started the interval.
            let top = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.2))
            let middle = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.5))
            let bottom = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.85))

            top.press(forDuration: 0.05, thenDragTo: middle)
            let hourAfterFirstDrag = hourDump.value as? String
            XCTAssertNotEqual(hourAtLaunch, hourAfterFirstDrag, "first drag never wrote a new hour — signpost precondition didn't fire")

            middle.press(forDuration: 0.05, thenDragTo: bottom)
            let hourAfterSecondDrag = hourDump.value as? String
            XCTAssertNotEqual(hourAfterFirstDrag, hourAfterSecondDrag, "second drag never wrote a new hour — signpost precondition didn't fire")

            app.terminate()
        }
    }
}
