import XCTest

/// T-033/PAS-13 fix pass — closes the exact gap qa's Build-Phase-1 report
/// named as the reason an 100%-reproducible crash slipped through 80 passing
/// unit tests: `DetailRouterTests` only ever calls `DetailRouter` directly,
/// as plain method calls, and never renders `HoodSheet`/`PlaceDetailModal`
/// inside the live `MapScreen` environment chain. That gap is exactly where
/// the bug lived — `.sheet`'s content didn't inherit `.environment(_:)` set
/// on the presenting view (see `MapScreen.swift`'s `.sheet` modifier comment
/// for the confirmed mechanism) — so a router-only test had nothing to catch
/// it. These two tests drive the real view hierarchy end to end: tap → sheet
/// presents → content actually renders and is populated, not just that the
/// tap handler fired.
///
/// Both tests tap the map at a fixed screen coordinate rather than looking up
/// `PlaceLayer`'s/`HoodButton`'s accessibility elements and tapping *those*.
/// Two independent things forced that choice, not stylistic preference:
///
/// 1. Bug 2 in this same fix pass gates pin/`HoodButton` *visibility* behind
///    close zoom (`MapScreen.showsNames`) — neither exists in the
///    accessibility tree at the cold-open city-wide camera this app always
///    launches into, so there is nothing to look up before zooming in.
/// 2. Zooming in from an XCUITest was tried first — both a synthesized pinch
///    and `XCUIElement.doubleTap()` — and neither reliably moved the camera.
///    Root cause traced, not just abandoned: `MapScreen`'s own
///    `SpatialTapGesture` (the `.simultaneousGesture` workaround for
///    FB19394663, `MapScreen.swift`) fires on the *first* tap of a
///    double-tap sequence and can open a sheet immediately, covering the map
///    before MapKit's built-in double-tap-to-zoom gesture recognizer
///    finishes recognizing the second tap — so the zoom never lands and the
///    sheet that DID open is a moving target for the second synthesized tap.
///
/// Tapping a known place's exact map coordinate is the actual `handleTap`
/// path a real finger takes (`PlaceHitTester` hit-tests raw place data, not
/// the pin's rendered glyph — a pin's Button and this gesture can both fire
/// for one physical tap, per that function's own comment) — so this remains
/// a faithful "tap a place pin" / "reach a Hood's sheet" test, just aimed at
/// the coordinate instead of a chrome element gated by a zoom this suite
/// deliberately isn't attempting. Coordinates were established empirically
/// against this project's fixed cold-open camera (`MapScreen.telAvivCityWide`)
/// and the bundled Build-Phase-1 fixture, both deterministic — no live
/// network, no random layout.
final class DetailSheetInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // The location permission system alert fires ~3.4s after cold open
        // (`PermissionPrompt.titleDidFinishFading`, 200ms after the title's
        // fade completes). Both tests tap well before that, but the monitor
        // is cheap insurance if a slow CI run pushes past it.
        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let dismiss = alert.buttons["Don't Allow"]
            guard dismiss.exists else { return false }
            dismiss.tap()
            return true
        }

        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testTappingPlacePinOpensPopulatedPlaceDetailModal() {
        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        // Lands on `kerem-suzana-yemenite-kitchen` (32.068407, 34.76525) —
        // one of three places clustered in `kerem-hateimanim`, well inside
        // `PlaceHitTester`'s tolerance at the cold-open camera.
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.376, dy: 0.560)).tap()

        let title = app.staticTexts["placeDetailTitle"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "PlaceDetailModal never rendered — this is exactly the environment-propagation crash T-033/PAS-13's qa pass found"
        )
        XCTAssertEqual(title.label, "Suzana Yemenite Kitchen", "modal rendered but with the wrong place's content")
    }

    func testTappingHoodOpensPopulatedHoodSheet() {
        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        // Lands inside `old-north`'s real polygon, away from any bundled
        // place — opens depth 1 the same way `HoodButton`'s tap does
        // (`detailRouter.openHood`, the same Site A `.sheet`).
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.498, dy: 0.515)).tap()

        let title = app.staticTexts["hoodSheetTitle"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "HoodSheet never rendered — this is exactly the environment-propagation crash T-033/PAS-13's qa pass found"
        )
        XCTAssertEqual(title.label, "Old North", "sheet rendered but for the wrong Hood")
    }
}
