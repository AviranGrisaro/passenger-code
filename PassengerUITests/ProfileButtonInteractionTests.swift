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

    /// **T-099/`PAS-99` (2026-08-09) replaces this test's original path.**
    /// This used to re-tap the nav-row `ProfileButton` to close Passport
    /// (TRD §9 row 2(c); the `chrome.toggle` exclusivity itself stays
    /// covered regardless, at `PassportWiringTests
    /// .openPassportTogglesClosedWhenAlreadyOpen`). `MapNavRow` is now
    /// hidden entirely while any `NavSurface` is presented (see
    /// `MapNavRow`'s header comment), so `app.buttons["Profile"]` — and the
    /// rest of the row — does not exist once Passport is open; there is
    /// nothing left to re-tap. `PassportSurface`'s own "Close" button is
    /// the dismiss path that survives this change, and this test now also
    /// confirms the row's hide/reappear contract directly.
    ///
    /// **`PAS-97` (merged into `PAS-99`):** `app.buttons["Close"]` resolves
    /// through the same `UIAccessibility` tree VoiceOver/Switch Control
    /// read, so its existence and exact `.label` below are live proof the
    /// surviving dismiss path is reachable and correctly labeled under
    /// both, not just by touch — see `MapNavRow`'s header comment.
    func testTappingCloseButtonDismissesPassportAndRestoresNavRow() {
        app.launch()

        let profileButton = app.buttons["Profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5), "ProfileButton never appeared in MapNavRow")
        profileButton.tap()

        let passportTitle = app.staticTexts["passportSurfaceTitle"]
        XCTAssertTrue(passportTitle.waitForExistence(timeout: 5), "PassportSurface never opened on first tap")

        XCTAssertFalse(app.buttons["Profile"].exists, "ProfileButton still in the tree while Passport is open")
        XCTAssertFalse(app.buttons["Search"].exists, "SearchButton still in the tree while Passport is open")
        XCTAssertFalse(app.buttons["Places"].exists, "PlacesButton still in the tree while Passport is open")
        XCTAssertFalse(app.otherElements["mapNavRow"].exists, "mapNavRow container still in the tree while Passport is open")

        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists, "Close button not reachable via the accessibility tree while Passport is open")
        XCTAssertEqual(closeButton.label, "Close", "Close button's VoiceOver/Switch Control label is wrong")
        closeButton.tap()

        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: passportTitle)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, "PassportSurface stayed open after tapping its Close button")

        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 5), "ProfileButton did not reappear after dismissing Passport")
        XCTAssertTrue(app.buttons["Search"].exists, "SearchButton did not reappear after dismissing Passport")
        XCTAssertTrue(app.buttons["Places"].exists, "PlacesButton did not reappear after dismissing Passport")
    }
}
