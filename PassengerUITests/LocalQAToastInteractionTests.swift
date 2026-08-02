import XCTest

/// tourist-trap-flag TRD §11 C14, §9 row 8(b)/(c): end-to-end coverage of
/// the two visible outcomes the ask loop can reach.
///
/// The `-uiTestResetLocalQA` launch argument (mirrors `-uiTestZoomedIn`'s own
/// precedent) wipes `local-qa.json` before each test's own launch — without
/// it, only a simulator's very first-ever run of this suite would see a
/// clean ledger; every subsequent run would find a prior test's answer still
/// on disk and fail for reasons that have nothing to do with the code under
/// test. Each test also uses its own synthetic place id, decoupled from the
/// bundled Places fixture entirely — `LocalQA/` never reads `PlaceCatalog`
/// (tourist-trap-flag TRD §2.2), so a placeID need not exist in the catalog
/// for the gate/store/toast to exercise it faithfully.
///
/// The `.record`/`lastAskedAt` sub-claims of §9 row 8(c) ("no record, cap
/// written") are covered at the unit layer (`LocalQAAnswerStoreTests`,
/// `LocalQAGateTests`), which can inspect the persisted file directly — a
/// UI test's separate process/sandbox can't read the app's own Application
/// Support directory, so this suite proves the two *visible* end-to-end
/// outcomes instead.
final class LocalQAToastInteractionTests: XCTestCase {
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

    func testAnsweringYesIsNeverAskedAgainForTheSamePlace() {
        let placeID = "uitest-local-qa-answered"
        app.launchArguments += ["-uiTestResetLocalQA", "-simulateLocalQAVisit", placeID]
        app.launch()

        let yesButton = app.buttons["localQAToastYes"]
        XCTAssertTrue(yesButton.waitForExistence(timeout: 5), "toast never appeared for the simulated visit")
        yesButton.tap()

        // The question is replaced by the confirmation line, then the whole
        // toast dismisses on its own (~1.6s, D6/§5) — wait for both rather
        // than asserting mid-animation.
        let confirmation = app.staticTexts["localQAToastConfirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2), "confirmation line never appeared after tapping Yes")
        XCTAssertFalse(app.staticTexts["localQAToastQuestion"].exists, "question text lingered after Yes was tapped")

        app.terminate()

        // Relaunch the same place, deliberately WITHOUT the reset argument
        // this time — the answer just recorded must persist and suppress a
        // second ask (§4.3 precedence rule 1, `.alreadyAnswered` beats every
        // trigger including `.debug`).
        app.launchArguments = ["-simulateLocalQAVisit", placeID]
        app.launch()

        let mapAfterRelaunch = app.maps.firstMatch
        XCTAssertTrue(mapAfterRelaunch.waitForExistence(timeout: 5), "map never appeared on relaunch")
        // The debug visit source fires ~1s after launch (`DebugVisitSource`)
        // — give it time to have fired and been suppressed before asserting
        // no toast ever showed.
        XCTAssertFalse(
            app.staticTexts["localQAToastQuestion"].waitForExistence(timeout: 3),
            "toast re-appeared for a place already answered — .alreadyAnswered must suppress every trigger, including .debug"
        )
    }

    func testIgnoringTheToastAutoDismissesWithNoReminderThisVisit() {
        let placeID = "uitest-local-qa-ignored"
        app.launchArguments += ["-uiTestResetLocalQA", "-simulateLocalQAVisit", placeID]
        app.launch()

        let question = app.staticTexts["localQAToastQuestion"]
        XCTAssertTrue(question.waitForExistence(timeout: 5), "toast never appeared for the simulated visit")

        // Auto-dismiss is 5s (C12) — wait past it without tapping either
        // button.
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: question)
        let result = XCTWaiter().wait(for: [expectation], timeout: 8)
        XCTAssertEqual(result, .completed, "toast did not auto-dismiss after being ignored")
    }
}
