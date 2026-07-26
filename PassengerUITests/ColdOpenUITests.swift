import XCTest

final class ColdOpenUITests: XCTestCase {

    /// Strategy: "No onboarding. Straight to the map + location permission."
    /// A cold open must land on the map with nothing in front of it.
    @MainActor
    func testColdOpenLandsOnMap() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.maps.firstMatch.waitForExistence(timeout: 10),
            "Cold open should land directly on the map"
        )
    }
}
