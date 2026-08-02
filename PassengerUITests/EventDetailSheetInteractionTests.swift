import XCTest

/// T-034 TRD §9 row 4a. Event markers render at every zoom (D2) — unlike
/// `DetailSheetInteractionTests`' place-pin case, no `-uiTestZoomedIn`
/// launch argument or camera gymnastics is needed here: `eventMarker-<id>`'s
/// `Button` is in the accessibility tree from the app's default cold-open
/// camera, so this test looks it up directly and taps it. Tapping the real
/// element (not a raw screen coordinate) still exercises D7's race — the
/// synthetic touch XCUITest delivers at that element's location reaches the
/// map's own `SpatialTapGesture` the same way a physical finger would, the
/// same property `DetailSheetInteractionTests`' coordinate-tap approach
/// relies on for the place-pin case.
final class EventDetailSheetInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Same insurance as `DetailSheetInteractionTests` — cheap even
        // though both tests here run well before the ~3.4s system prompt.
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

    func testTappingEventMarkerOpensEventDetailSheetNotAHoodSheet() {
        app.launch()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "Map never appeared")

        // seed-0001, "Rooftop set, Levinsky" (Resources/events-tel-aviv-seed.json)
        // — Florentin, overlapping hour offset 0 by construction (starts an
        // hour before anchor, runs four hours). Events render at every zoom
        // (D2), so this marker is on screen at the default cold-open camera.
        let marker = app.buttons["eventMarker-seed-0001"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5), "Event marker never appeared at the default cold-open camera")
        marker.tap()

        let title = app.staticTexts["eventDetailTitle"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "EventDetailModal never rendered from a single tap on the event marker"
        )
        XCTAssertEqual(title.label, "Rooftop set, Levinsky", "sheet rendered but for the wrong event")

        // D7's race: the map's own SpatialTapGesture must not also resolve
        // this tap to a Hood underneath the marker.
        XCTAssertFalse(
            app.staticTexts["hoodSheetTitle"].exists,
            "A Hood sheet opened over the tapped event — the SpatialTapGesture race D7 exists to close"
        )
    }
}
