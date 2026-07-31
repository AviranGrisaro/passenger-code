import XCTest

/// T-033/PAS-13 acceptance fix pass. The earlier version of this file
/// encoded the tap/pin zoom-gate mismatch as expected behaviour instead of
/// testing for it: it asserted a tap at a bundled place's exact cold-open
/// coordinate opened `PlaceDetailModal` (the bug — `handleTap`'s place-hit
/// branch had no `showsNames` guard even though the pin `ForEach` did, see
/// `MapScreen.swift`'s `handleTap`), and its Hood test deliberately picked
/// `old-north` specifically *because* it sits away from every bundled place,
/// sidestepping the bug rather than exercising it. `product`'s acceptance
/// REJECT (`hood-place-detail.md` req 1 bullet 4, req 3 bullet 4) named both
/// problems directly.
///
/// These two tests now cover the fixed contract instead:
///
/// 1. `testTappingPopulatedHoodAtColdOpenOpensHoodSheet` — at the app's
///    default cold-open camera (`MapScreen.telAvivCityWide`, `showsNames ==
///    false`, no pins drawn), tapping a bundled place's exact coordinate
///    inside `kerem-hateimanim` opens *that Hood's sheet*, never a place
///    modal for a pin the user cannot see (PRD req 1 bullet 4). This is the
///    exact scenario the REJECT's arithmetic covers — every point inside a
///    populated Hood's real polygon falls within the live tap tolerance of
///    one of its own places — so this coordinate stands in for "anywhere in
///    a populated Hood," not a coordinate picked to dodge the bug.
/// 2. `testTappingPlacePinOpensPopulatedPlaceDetailModalWhenZoomedIn` — the
///    pin-tap path still needs to work once the zoom gate is actually open.
///    Launched with `-uiTestZoomedIn` (`MapScreen.initialCameraRegion`),
///    which starts the app already zoomed in past `nameLabelSpanThreshold`
///    instead of the default city-wide camera, so the tap hits a genuinely
///    visible pin through the now-gated `handleTap` path rather than relying
///    on the ungated bug this suite used to depend on.
///
/// Both tests tap the map at a fixed screen coordinate rather than looking up
/// `PlaceLayer`'s/`HoodButton`'s accessibility elements and tapping *those*,
/// for the same two reasons as the original version of this file:
///
/// 1. Pin/`HoodButton` *visibility* is gated behind close zoom
///    (`MapScreen.showsNames`) — neither exists in the accessibility tree at
///    the cold-open city-wide camera, so there is nothing to look up before
///    zooming in.
/// 2. Zooming in from an XCUITest gesture was tried first — both a
///    synthesized pinch and `XCUIElement.doubleTap()` — and neither reliably
///    moved the camera. Root cause traced, not just abandoned: `MapScreen`'s
///    own `SpatialTapGesture` (the `.simultaneousGesture` workaround for
///    FB19394663) fires on the *first* tap of a double-tap sequence and can
///    open a sheet immediately, covering the map before MapKit's built-in
///    gesture recognizer finishes recognizing the second tap — so the zoom
///    never lands and the sheet that DID open is a moving target for the
///    second synthesized tap. `-uiTestZoomedIn` sidesteps the gesture
///    problem entirely by setting the *initial* camera instead of trying to
///    move it mid-test.
///
/// Tapping a known place's exact map coordinate is the actual `handleTap`
/// path a real finger takes (`PlaceHitTester` hit-tests raw place data, not
/// the pin's rendered glyph — a pin's Button and this gesture can both fire
/// for one physical tap, per that function's own comment) — so this remains
/// a faithful "tap a place pin" / "tap inside a Hood" test, just aimed at the
/// coordinate instead of a chrome element gated by the same zoom this suite
/// deliberately isn't attempting to reach via gesture. Coordinates were
/// established empirically against this project's fixed cold-open camera
/// (`MapScreen.telAvivCityWide`) and the bundled Build-Phase-1 fixture, both
/// deterministic — no live network, no random layout.
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

        // Launch is deferred to each test, not done here: the zoomed-in test
        // needs to set `launchArguments` before `launch()` is called.
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testTappingPopulatedHoodAtColdOpenOpensHoodSheet() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        // `kerem-suzana-yemenite-kitchen`'s coordinate (32.068407, 34.76525)
        // — inside `kerem-hateimanim`'s real polygon, ~231m from its
        // centroid, and inside `PlaceHitTester`'s live tap tolerance at this
        // camera. Before the fix this opened `PlaceDetailModal` for a pin
        // that isn't drawn at this zoom; it must now fall through to
        // `kerem-hateimanim`'s own Hood sheet.
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.376, dy: 0.560)).tap()

        let hoodTitle = app.staticTexts["hoodSheetTitle"]
        XCTAssertTrue(
            hoodTitle.waitForExistence(timeout: 5),
            "HoodSheet never rendered — a tap inside a populated Hood at cold-open zoom must fall through to the Hood, not do nothing"
        )
        XCTAssertEqual(hoodTitle.label, "Kerem HaTeimanim", "sheet rendered but for the wrong Hood")
        XCTAssertFalse(
            app.staticTexts["placeDetailTitle"].exists,
            "PlaceDetailModal rendered for a pin that isn't drawn at this zoom — this is the exact T-033/PAS-13 acceptance REJECT (req 1 bullet 4 / req 3 bullet 4)"
        )
    }

    func testTappingPlacePinOpensPopulatedPlaceDetailModalWhenZoomedIn() {
        // `-uiTestZoomedIn` (`MapScreen.initialCameraRegion`) starts the app
        // already zoomed in past `nameLabelSpanThreshold`, centered on this
        // same place, so its pin is genuinely visible and `handleTap`'s
        // place branch — now gated on `showsNames` — is actually open.
        app.launchArguments += ["-uiTestZoomedIn"]
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let title = app.staticTexts["placeDetailTitle"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "PlaceDetailModal never rendered when zoomed in past the pin/tap zoom gate"
        )
        XCTAssertEqual(title.label, "Suzana Yemenite Kitchen", "modal rendered but with the wrong place's content")
    }
}
