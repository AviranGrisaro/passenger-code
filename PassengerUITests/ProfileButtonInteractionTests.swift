import XCTest

/// T-037/PAS-28 follow-up: `ProfileButton`'s wiring into `MapNavRow` (TRD
/// §2.4/§4.6, §11 C7) — landed once `MapNavRow.swift` existed (T-038's
/// build) and settled. `PassportWiringTests` already covers
/// `MapScreen.openPassport`'s open/close/toggle contract directly against
/// `DetailRouter`/`MapChromeState`, for the same reason that file gives for
/// skipping "button-tap plumbing that needs a live SwiftUI environment" at
/// the unit level. This is the other half: a real tap on the real button,
/// in a live app, actually reaches that function — the same split
/// `DetailSheetInteractionTests`/`LocalQAToastInteractionTests` draw
/// between their own unit-level stores and this UI-level interaction.
final class ProfileButtonInteractionTests: XCTestCase {
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

    func testTappingProfileButtonOpensPassport() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        let profileButton = app.buttons["Profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5), "ProfileButton never appeared in MapNavRow")
        profileButton.tap()

        let passportTitle = app.staticTexts["passportSurfaceTitle"]
        XCTAssertTrue(
            passportTitle.waitForExistence(timeout: 5),
            "PassportSurface never rendered — ProfileButton's tap never reached MapScreen.openPassport"
        )
        XCTAssertEqual(passportTitle.label, "Passport")
    }

    func testTappingProfileButtonAgainDismissesPassport() {
        app.launch()

        let profileButton = app.buttons["Profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5), "ProfileButton never appeared in MapNavRow")
        profileButton.tap()

        let passportTitle = app.staticTexts["passportSurfaceTitle"]
        XCTAssertTrue(passportTitle.waitForExistence(timeout: 5), "PassportSurface never opened on first tap")

        // Re-tapping the same button is the toggle-closed path (TRD §9 row
        // 2(c); `PassportWiringTests
        // .openPassportTogglesClosedWhenAlreadyOpen` already covers this at
        // the `chrome.toggle` level) — this confirms the real button
        // reaches it too, and that the nav row stays hit-testable while
        // Passport is open (§2.4, D9) rather than being covered by its own
        // scrim.
        profileButton.tap()
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: passportTitle)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, "PassportSurface stayed open after re-tapping ProfileButton")
    }
}
