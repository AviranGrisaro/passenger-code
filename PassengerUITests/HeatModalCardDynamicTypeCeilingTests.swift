import XCTest

/// TRD §9 row 5b (rewritten at v5, `PAS-51` findings 1 and 4) and row 6(c)
/// — the table's own text says 6(c) is "discharged by row 5b's (b)/(b2)
/// captures... not re-derived here," so this one test file covers both
/// rows, not two.
///
/// Exercises C15's launch-argument seam (`UITestOverrides`) to render
/// `HeatModalCard` at a real accessibility text size, against a real fixed
/// clock, rather than standing in `HeatModalCardLayoutGuardTests`' source
/// grep (demoted at v5 to a regression backstop that explicitly cannot
/// discharge this row) or a "next day" positive control that only fired
/// when the suite happened to run after local noon (`PAS-51` finding 4).
///
/// **v4 asked for a capture at AX5; that became unsatisfiable once
/// `HeatModalCard` gained its `.accessibility3` ceiling** — a clamped card
/// never renders at AX5 by design. So this checks the card at its own
/// ceiling, plus that requesting AX5 renders *identically* to the ceiling
/// (proof the clamp actually binds), rather than asserting a state the
/// design forbids.
///
/// **Disclosed scope limitation, not silently narrowed:** row 5b (a)/(ii)
/// ask for the offset numeral, clock label, and "next day" pill's frames
/// *individually*. `HourReadout` combines them into one accessibility
/// element (`.accessibilityElement(children: .combine)`) for VoiceOver —
/// "one spoken unit," not three stops — which is also what keeps them from
/// being separately queryable from XCUITest. Splitting that apart is an
/// accessibility-behavior change to `HourReadout` this pass does not make;
/// the checks below use the combined `hourReadout` element as the
/// container-level proxy TRD §9's own text allows ("or on-device with
/// frames read from the accessibility hierarchy"), not a per-element
/// breakdown. Flagged for `architect`/`qa` rather than claimed complete.
final class HeatModalCardDynamicTypeCeilingTests: XCTestCase {
    /// One fixed clock for the whole test — 23:00 in *this host's* local
    /// timezone (the simulator inherits the Mac's), today. `anchorHour` is
    /// this instant's UTC-hour floor, so +12h from it lands roughly 11:00
    /// local the *next* day regardless of what wall-clock hour the suite
    /// actually runs at — the exact gap `PAS-51` finding 4 raised against
    /// the pre-C15 test, which only exercised this branch after local noon.
    private static let fixedNowISO8601: String = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 0
        components.second = 0
        let fixedNow = calendar.date(from: components) ?? Date()
        return ISO8601DateFormatter().string(from: fixedNow)
    }()

    private struct Capture {
        let cardFrame: CGRect
        let navRowFrame: CGRect
        let readoutFrame: CGRect
        let readoutLabel: String
        /// The full window frame, used to derive the safe-area bottom the
        /// same way `HeatModalCardLayoutTests` does — captured per-launch
        /// since each accessibility size is its own app process.
        let windowFrame: CGRect
    }

    /// Launches a fresh app instance — XCUITest launch arguments can only
    /// be set before `launch()`, so each accessibility size gets its own
    /// process rather than one app juggling three live states — opens the
    /// heat modal, drags to +12h, and reads back the frames row 5b needs.
    /// Terminates the app before returning; each call owns its own process
    /// lifetime.
    private func capture(dynamicTypeSizeArgument: String?, name: StaticString = #function, line: UInt = #line) -> Capture {
        let app = XCUIApplication()
        var arguments = ["-uiTestNow", Self.fixedNowISO8601]
        if let dynamicTypeSizeArgument {
            arguments += ["-uiTestDynamicTypeSize", dynamicTypeSizeArgument]
        }
        app.launchArguments = arguments
        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let dismiss = alert.buttons["Don't Allow"]
            guard dismiss.exists else { return false }
            dismiss.tap()
            return true
        }
        app.launch()

        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 5), "Map never appeared", line: line)
        let heatButton = app.buttons["Heat"]
        XCTAssertTrue(heatButton.waitForExistence(timeout: 5), "HeatButton never appeared", line: line)
        heatButton.tap()

        let slider = app.sliders["hourSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "hourSlider never rendered", line: line)
        slider.adjust(toNormalizedSliderPosition: 1.0)

        let card = app.otherElements["heatModalCard"]
        let navRow = app.otherElements["mapNavRow"]
        let readout = app.staticTexts["hourReadout"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "heatModalCard never rendered", line: line)
        XCTAssertTrue(navRow.waitForExistence(timeout: 5), "mapNavRow never rendered", line: line)
        XCTAssertTrue(readout.waitForExistence(timeout: 5), "hourReadout never rendered", line: line)

        let result = Capture(
            cardFrame: card.frame, navRowFrame: navRow.frame, readoutFrame: readout.frame,
            readoutLabel: readout.label, windowFrame: app.windows.firstMatch.frame
        )
        app.terminate()
        return result
    }

    /// Row 5b (a)/(b)/(b2)/(c)/(i)/(ii)/(iii)/wrap-check, and row 6(c) —
    /// per the table's own text, discharged here rather than re-derived.
    func testCardAtItsCeilingClearsTheNavRowAndTheClampBindsAtAX5() {
        let defaultCapture = capture(dynamicTypeSizeArgument: nil)
        let ceilingCapture = capture(dynamicTypeSizeArgument: "accessibility3")
        let ax5Capture = capture(dynamicTypeSizeArgument: "accessibility5")
        let captures: [(String, Capture)] = [
            ("default", defaultCapture), ("ceiling (AX3)", ceilingCapture), ("requested AX5", ax5Capture),
        ]

        // Counts and non-emptiness first (standing rule 1) — a zero-sized
        // frame anywhere below makes every geometry claim about it vacuous.
        for (name, capture) in captures {
            XCTAssertGreaterThan(capture.cardFrame.width, 0, "\(name) capture: heatModalCard rendered zero-width")
            XCTAssertGreaterThan(capture.cardFrame.height, 0, "\(name) capture: heatModalCard rendered zero-height")
            XCTAssertGreaterThan(capture.navRowFrame.width, 0, "\(name) capture: mapNavRow rendered zero-width")
            XCTAssertGreaterThan(capture.navRowFrame.height, 0, "\(name) capture: mapNavRow rendered zero-height")
            XCTAssertGreaterThan(capture.readoutFrame.width, 0, "\(name) capture: hourReadout rendered zero-width")
            XCTAssertGreaterThan(capture.readoutFrame.height, 0, "\(name) capture: hourReadout rendered zero-height")
        }

        // Positive control (standing rule 2), deterministic under C15's
        // pinned clock rather than wall-clock-dependent: both tokens
        // present in full, in every capture.
        for (name, capture) in captures {
            XCTAssertTrue(
                capture.readoutLabel.contains("+12h"),
                "\(name) capture: hourReadout label missing \"+12h\": \(capture.readoutLabel)"
            )
            XCTAssertTrue(
                capture.readoutLabel.contains("next day"),
                "\(name) capture: hourReadout label missing \"next day\": \(capture.readoutLabel)"
            )
        }

        // (i)/(ii): non-intersection, checked independently at default size
        // and at the ceiling — the card can clear the nav row at one size
        // and not the other, which is why both are asserted rather than one
        // standing in for the other.
        for (name, capture) in [("default", defaultCapture), ("ceiling (AX3)", ceilingCapture)] {
            XCTAssertFalse(
                capture.cardFrame.intersects(capture.navRowFrame),
                "\(name) capture: heatModalCard \(capture.cardFrame) overlaps mapNavRow \(capture.navRowFrame)"
            )
            XCTAssertGreaterThanOrEqual(
                capture.navRowFrame.minY - capture.cardFrame.maxY, 8,
                "\(name) capture: gap between heatModalCard and mapNavRow is under the 8pt visible-separation floor"
            )
            XCTAssertFalse(
                capture.readoutFrame.intersects(capture.navRowFrame),
                "\(name) capture: hourReadout \(capture.readoutFrame) overlaps mapNavRow \(capture.navRowFrame)"
            )

            // (iii): never `bottom: 0` — falsified directly against the
            // safe-area bottom, same 34pt home-indicator derivation as
            // `HeatModalCardLayoutTests`'s equivalent default-size check,
            // re-run here at the ceiling too since the card grows with text
            // size and a default-size clearance says nothing about the
            // largest one.
            let safeAreaBottom = capture.navRowFrame.isEmpty ? capture.cardFrame.maxY + 1 : capture.windowFrame.maxY - 34
            XCTAssertLessThan(
                capture.cardFrame.maxY, safeAreaBottom,
                "\(name) capture: heatModalCard's bottom edge \(capture.cardFrame.maxY) reaches or passes the safe-area bottom \(safeAreaBottom)"
            )
        }

        // (b2): requesting AX5 must render *identically* to the ceiling —
        // that equality is the clamp binding, and it is the only claim
        // about AX5 this design permits once the card has a ceiling below
        // it. A 1pt tolerance absorbs floating-point layout noise between
        // separate app launches without hiding a real size difference.
        assertFramesEqual(ceilingCapture.cardFrame, ax5Capture.cardFrame, tolerance: 1, message: "heatModalCard")
        assertFramesEqual(ceilingCapture.readoutFrame, ax5Capture.readoutFrame, tolerance: 1, message: "hourReadout")

        // Sanity check that C15's override actually changed rendering at
        // all — required by TRD §9's standing rule: "a row is BLOCKED only
        // if C15's seam itself fails to take effect, and that is a finding
        // to report, not a reason to substitute a source grep." If the
        // ceiling capture isn't measurably larger than the default one,
        // `-uiTestDynamicTypeSize` did not take effect and this whole row
        // is unrun, not passed — that failure must surface here, not be
        // silently weakened away.
        XCTAssertGreaterThan(
            ceilingCapture.readoutFrame.height, defaultCapture.readoutFrame.height * 1.05,
            "ceiling capture's hourReadout is not measurably taller than the default capture's — "
                + "-uiTestDynamicTypeSize did not take effect (TRD §9 standing rule: BLOCKED, not a passed row)"
        )

        // The wrap check — what F2 actually was. Mid-token wrapping is
        // invisible to `.label`, so it is checked as height and
        // containment on the combined `hourReadout` element (the
        // container-level proxy this file's header discloses): a wrapped
        // pill would grow the whole readout row well past a one-line
        // height ratio and/or push it outside the card's own bounds.
        let heightRatio = ceilingCapture.readoutFrame.height / defaultCapture.readoutFrame.height
        XCTAssertLessThan(
            heightRatio, 2,
            "hourReadout's height at the ceiling (\(ceilingCapture.readoutFrame.height)) is more than double its "
                + "default-size height (\(defaultCapture.readoutFrame.height)) — consistent with a wrapped line"
        )
        XCTAssertTrue(
            ceilingCapture.cardFrame.contains(ceilingCapture.readoutFrame),
            "hourReadout \(ceilingCapture.readoutFrame) is not fully contained within heatModalCard "
                + "\(ceilingCapture.cardFrame) at the ceiling — a wrapped or overflowing readout escapes the card"
        )
    }

    private func assertFramesEqual(
        _ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat, message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(lhs.width, rhs.width, accuracy: tolerance, "\(message) width differs between the ceiling and AX5 captures", file: file, line: line)
        XCTAssertEqual(lhs.height, rhs.height, accuracy: tolerance, "\(message) height differs between the ceiling and AX5 captures", file: file, line: line)
        XCTAssertEqual(lhs.minX, rhs.minX, accuracy: tolerance, "\(message) x-position differs between the ceiling and AX5 captures", file: file, line: line)
        XCTAssertEqual(lhs.minY, rhs.minY, accuracy: tolerance, "\(message) y-position differs between the ceiling and AX5 captures", file: file, line: line)
    }
}
