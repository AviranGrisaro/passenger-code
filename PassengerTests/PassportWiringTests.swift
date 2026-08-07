import Testing
@testable import Passenger

/// passport TRD §9 row 2, §11 C11. A separate file from `MapScreenTests.swift`
/// on purpose — same reason `PlaceTouristTrapDecodeTests.swift` gives for its
/// own split from `PlaceCatalogTests.swift`: that file is concurrently owned
/// by another in-flight task's build in this working tree.
///
/// The side effect lives in a static function over the two objects it
/// touches (`MapScreen.openPassport`), so this is unit-tested directly
/// rather than through button-tap plumbing that needs a live SwiftUI
/// environment — same construction as `MapScreen.openPlacesList`/
/// `handlePresentedSurfaceChange`, which `MapScreenTests.swift` already
/// tests this way.
@Suite("Passport chrome wiring")
@MainActor
struct PassportWiringTests {
    // MARK: - §9 row 2(c): opening Passport while a Hood sheet is open closes it

    @Test("openPassport closes an open Hood sheet and presents .profile")
    func openPassportClosesHoodSheet() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        let hood = Hood(
            id: "florentin", name: "Florentin", ring: [], boundingRect: .null,
            centroid: .init(latitude: 0, longitude: 0), blurb: nil, isTouristTrap: nil,
            designatedForProgression: false
        )
        router.openHood(hood)

        MapScreen.openPassport(router: router, chrome: chrome)

        #expect(router.hood == nil)
        #expect(chrome.presented == .profile)
    }

    @Test("openPassport on an already-.profile chrome closes it — toggle, not a second open")
    func openPassportTogglesClosedWhenAlreadyOpen() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        chrome.toggle(.profile)

        MapScreen.openPassport(router: router, chrome: chrome)

        #expect(chrome.presented == nil)
    }

    // MARK: - §9 row 2(b): switching away from Passport is one clean transition

    @Test("toggling to .search while Passport is open leaves .profile gone, .search presented, no stacked state")
    func switchingToSearchClosesPassportCleanly() {
        let chrome = MapChromeState()
        chrome.toggle(.profile)

        chrome.toggle(.search)

        #expect(chrome.presented == .search)
    }

    // MARK: - §9 row 2(e), the structural proxy for row 2(d): nothing in this
    // feature reads or writes `camera`/`selectedHour` — checked as source
    // absence in `PassportAbsenceGateTests`, not here; named so a reader of
    // this file finds the other half of the same requirement.
}
