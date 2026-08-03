import Testing
@testable import Passenger

/// T-032 TRD §4.1, §5. Same construction as `PassportWiringTests`: the side
/// effect lives in a static function over the two objects it touches
/// (`MapScreen.openHeat`), unit-tested directly rather than through
/// button-tap plumbing that needs a live SwiftUI environment.
@Suite("Heat modal chrome wiring")
@MainActor
struct HeatWiringTests {
    @Test("openHeat closes an open Hood sheet and presents .heat")
    func openHeatClosesHoodSheet() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        let hood = Hood(
            id: "florentin", name: "Florentin", ring: [], boundingRect: .null,
            centroid: .init(latitude: 0, longitude: 0), blurb: nil, isTouristTrap: nil,
            designatedForProgression: false
        )
        router.openHood(hood)

        MapScreen.openHeat(router: router, chrome: chrome)

        #expect(router.hood == nil)
        #expect(chrome.presented == .heat)
    }

    @Test("openHeat on an already-.heat chrome closes it — toggle, not a second open")
    func openHeatTogglesClosedWhenAlreadyOpen() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        chrome.toggle(.heat)

        MapScreen.openHeat(router: router, chrome: chrome)

        #expect(chrome.presented == nil)
    }

    @Test("toggling to .places while the heat modal is open leaves .heat gone, .places presented, no stacked state")
    func switchingToPlacesClosesHeatCleanly() {
        let chrome = MapChromeState()
        chrome.toggle(.heat)

        chrome.toggle(.places)

        #expect(chrome.presented == .places)
    }

    @Test("openHeat never touches selectedHour — that's the whole point of req 4 (TRD §4.1)")
    func openHeatDoesNotTouchSelectedHour() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        let store = DensityStore()
        store.selectedHour = 7

        MapScreen.openHeat(router: router, chrome: chrome)

        #expect(store.selectedHour == 7)
    }
}
