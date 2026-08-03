import XCTest

/// T-032 TRD §9 row 7 / C13 — **the check the TRD names as blocking**: C13
/// "is not done until the first item passes," and this is that item. D7's
/// central claim ("MapKit's pan recognizer is never in the recognizer chain
/// of a touch inside the 24pt edge zone") is derived from hit-test
/// reasoning alone, and §2.4/§10 both say plainly that reasoning of that
/// kind is not the last word on this feature's most load-bearing claim —
/// this has to be confirmed on a rendered app, not asserted.
///
/// **How the camera is observed.** Neither `MapScreen.camera` nor
/// `MKCoordinateRegion` is otherwise readable from an XCUITest process.
/// Launching with `-uiTestExposeCameraRegion` turns on two invisible,
/// otherwise-absent accessibility elements (`MapScreen.swift`,
/// `isExposingCameraRegionForTests`) that mirror the live camera region and
/// `selectedHour` as plain strings — the same class of test-only seam
/// `-uiTestZoomedIn` already established in this file's sibling
/// `DetailSheetInteractionTests`. Neither element, nor the launch argument
/// that reveals them, exists in a real launch.
///
/// **How "mid-drag" is sampled.** `XCUIElement.press(forDuration:thenDragTo:)`
/// is a single synthesized gesture that blocks until it completes — there
/// is no callback mid-flight to read state from. This suite instead runs
/// the sweep as **two consecutive complete drags** (top-of-band→middle,
/// middle→bottom-of-band) and reads the camera dump after each — touch-down
/// is the value read before either drag starts, "mid-drag" is the value
/// after the first, "onEnded" is the value after the second. This is a
/// stronger check than sampling once mid-gesture, not a weaker
/// approximation of it: it proves the invariant holds across two
/// independent gesture lifecycles, not only within one.
final class EdgeHourZoneInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    /// Well inside the 24pt capture zone on any current device width
    /// (390–430pt) — `0.02 * width` is 8–9pt, comfortably short of the
    /// 24pt boundary.
    private static let leadingEdgeX: CGFloat = 0.02
    /// A point clearly outside the zone, used for the "pan starts outside
    /// the band" control case.
    private static let mapCenterX: CGFloat = 0.5

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiTestExposeCameraRegion"]

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

    /// **The blocking check (§9 row 7e, C13 item 1).** A normal, in-band,
    /// vertical edge drag must move `selectedHour` while leaving
    /// `camera`/`MKCoordinateRegion` byte-identical throughout.
    func testInBandVerticalDragMovesTheHourAndLeavesTheCameraUntouched() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        let cameraDump = app.otherElements["cameraRegionDebugDump"]
        let hourDump = app.otherElements["selectedHourDebugDump"]
        XCTAssertTrue(cameraDump.waitForExistence(timeout: 5), "camera debug dump never appeared")
        XCTAssertTrue(hourDump.waitForExistence(timeout: 5), "selectedHour debug dump never appeared")

        let touchDownCamera = cameraDump.value as? String
        let touchDownHour = hourDump.value as? String
        XCTAssertNotNil(touchDownCamera)
        XCTAssertEqual(touchDownHour, "0", "cold launch must start at hour 0 ('Now')")

        let top = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.2))
        let middle = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.5))
        let bottom = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.85))

        top.press(forDuration: 0.05, thenDragTo: middle)
        let midDragCamera = cameraDump.value as? String
        let midDragHour = hourDump.value as? String

        middle.press(forDuration: 0.05, thenDragTo: bottom)
        let onEndedCamera = cameraDump.value as? String
        let onEndedHour = hourDump.value as? String

        // The central claim: byte-identical at all three samples, same
        // comparison method §9 row 2c already uses (string equality here
        // stands in for that, since the dump is a fixed-precision
        // formatted string of the region's own components).
        XCTAssertEqual(touchDownCamera, midDragCamera, "camera moved during the first half of an in-band vertical drag")
        XCTAssertEqual(midDragCamera, onEndedCamera, "camera moved during the second half of an in-band vertical drag")

        // And the hour actually moved — the other half of row 7e's pass
        // condition. Downward finger movement reads as "later" (§4.9).
        XCTAssertNotEqual(touchDownHour, midDragHour, "selectedHour never moved during the first drag segment")
        XCTAssertNotEqual(midDragHour, onEndedHour, "selectedHour never moved during the second drag segment")

        // §4.8's "also consumed: taps inside the strip" / the drag must
        // not also fire `MapScreen.handleTap` mid-drag (C13 item 4).
        XCTAssertFalse(app.staticTexts["hoodSheetTitle"].exists, "an edge drag must never open a Hood sheet")
        XCTAssertFalse(app.staticTexts["placeDetailTitle"].exists, "an edge drag must never open a place modal")
    }

    /// Rule (b), §9 row 7b: a horizontal-dominant drag starting inside the
    /// band is inert for its whole lifetime — no hour write, no camera
    /// movement, at all.
    func testHorizontalDominantDragInsideTheBandChangesNeitherHourNorCamera() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        let cameraDump = app.otherElements["cameraRegionDebugDump"]
        let hourDump = app.otherElements["selectedHourDebugDump"]
        XCTAssertTrue(cameraDump.waitForExistence(timeout: 5))
        XCTAssertTrue(hourDump.waitForExistence(timeout: 5))

        let before = cameraDump.value as? String
        let hourBefore = hourDump.value as? String

        // Starts inside the zone (small dx), moves mostly horizontally —
        // `abs(dx) > abs(dy)` at the gesture's own first movement.
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.5))
        let end = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX + 0.15, dy: 0.51))
        start.press(forDuration: 0.05, thenDragTo: end)

        let after = cameraDump.value as? String
        let hourAfter = hourDump.value as? String

        XCTAssertEqual(before, after, "a horizontal-dominant drag inside the band must never move the camera")
        XCTAssertEqual(hourBefore, hourAfter, "a horizontal-dominant drag inside the band must never write an hour")
    }

    /// §9 row 7(d1)/(d2), C13 item 5: with a Hood sheet presented, the edge
    /// zone leaves the hierarchy entirely — a drag over the same screen
    /// region must not produce a track or move the hour, at either detent.
    func testEdgeZoneIsInertWhileAHoodSheetIsPresented() {
        // `hoodButton` only renders at close zoom (`showsNames`) — the
        // cold-open city-wide camera doesn't reach it. `-uiTestZoomedIn`
        // (`MapScreen.initialCameraRegion`, `DetailSheetInteractionTests`'
        // own seam) starts the app already zoomed in on a real bundled
        // place, past that threshold, deterministically.
        app.launchArguments += ["-uiTestZoomedIn"]
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        let hoodButton = app.buttons["hoodButton"]
        XCTAssertTrue(hoodButton.waitForExistence(timeout: 5), "hoodButton never appeared once zoomed in")
        hoodButton.tap()

        let hoodTitle = app.staticTexts["hoodSheetTitle"]
        XCTAssertTrue(hoodTitle.waitForExistence(timeout: 5), "HoodSheet never opened")

        let hourDump = app.otherElements["selectedHourDebugDump"]
        let hourBefore = hourDump.value as? String

        let top = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.2))
        let bottom = map.coordinate(withNormalizedOffset: CGVector(dx: Self.leadingEdgeX, dy: 0.85))
        top.press(forDuration: 0.05, thenDragTo: bottom)

        let hourAfter = hourDump.value as? String
        XCTAssertEqual(hourBefore, hourAfter, "the edge zone must be structurally absent while a Hood sheet is presented")
    }
}
