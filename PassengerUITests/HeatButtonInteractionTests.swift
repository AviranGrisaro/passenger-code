import XCTest

/// T-032 TRD §2.4/§4.6, §11 C2/C5. Same construction as
/// `ProfileButtonInteractionTests`: `HeatWiringTests` already covers
/// `MapScreen.openHeat`'s open/close/toggle contract directly against
/// `DetailRouter`/`MapChromeState`; this is the other half — a real tap on
/// the real button, in a live app, actually reaches it, and the slider it
/// opens actually moves the selected hour.
final class HeatButtonInteractionTests: XCTestCase {
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

    func testTappingHeatButtonOpensTheModal() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        let heatButton = app.buttons["Heat"]
        XCTAssertTrue(heatButton.waitForExistence(timeout: 5), "HeatButton never appeared in MapNavRow")
        heatButton.tap()

        let title = app.staticTexts["heatModalCardTitle"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "HeatModalCard never rendered — HeatButton's tap never reached MapScreen.openHeat"
        )
        XCTAssertEqual(title.label, "Map hour")

        let slider = app.sliders["hourSlider"]
        XCTAssertTrue(slider.exists, "hourSlider never rendered inside the open modal")
    }

    func testTappingHeatButtonAgainDismissesTheModal() {
        app.launch()

        let heatButton = app.buttons["Heat"]
        XCTAssertTrue(heatButton.waitForExistence(timeout: 5), "HeatButton never appeared in MapNavRow")
        heatButton.tap()

        let title = app.staticTexts["heatModalCardTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "HeatModalCard never opened on first tap")

        // Re-tapping the same button is the toggle-closed path (TRD §4.1) —
        // confirms the real button reaches `chrome.toggle(.heat)`'s
        // already-open branch, and that the nav row stays hit-testable
        // while the modal is up (§2.3 z7).
        heatButton.tap()
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: title)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, "HeatModalCard stayed open after re-tapping HeatButton")
    }

    func testDraggingTheSliderMovesTheSelectedHourAndRepaintsSilently() {
        app.launch()

        let heatButton = app.buttons["Heat"]
        XCTAssertTrue(heatButton.waitForExistence(timeout: 5), "HeatButton never appeared in MapNavRow")
        heatButton.tap()

        let slider = app.sliders["hourSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "hourSlider never rendered")
        let initialValue = (slider.value as? String) ?? ""
        XCTAssertTrue(
            initialValue.hasPrefix("Now"),
            "cold launch must start the control at 'Now' (req 3), got: \(initialValue)"
        )

        // Drive the control the way TRD §9's own verification table does —
        // `adjust(toNormalizedSliderPosition:)`, not a synthesized drag —
        // to the far end of the 0...12 range.
        slider.adjust(toNormalizedSliderPosition: 1.0)

        let valueAfterAdjust = (slider.value as? String) ?? ""
        XCTAssertFalse(
            valueAfterAdjust.hasPrefix("Now"),
            "moving the slider to its maximum must move off 'Now', got: \(valueAfterAdjust)"
        )
    }
}
