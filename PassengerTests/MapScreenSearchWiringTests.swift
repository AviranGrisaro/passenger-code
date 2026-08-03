import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers search-quick-filters TRD §4.9/§4.6/D11 — `MapScreen`'s static,
/// testable wiring functions for search, same construction as
/// `MapScreenD8WiringTests` covers for `.places`/`.profile`: the side effect
/// lives in a static function over the objects it touches, so §9 rows 1 and
/// 7 are unit-tested directly rather than through button-tap plumbing that
/// needs a live SwiftUI environment.
@Suite("MapScreen search presentation wiring")
@MainActor
struct MapScreenSearchWiringTests {
    private static func makeHood(id: String) -> Hood {
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10)]
        return Hood(
            id: id, name: id, ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false
        )
    }

    private static func makePlace(id: String) -> Place {
        Place(
            id: id, name: id, category: .eatDrink, hoodID: "florentin",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            permanentlyClosed: false, placeType: "cafe", isTouristTrap: nil, keywords: []
        )
    }

    // MARK: - §9 row 1(c)/(d): opening `.search`

    @Test("opening .search with a Hood sheet already open closes it and presents .search")
    func openSearchClosesOpenHood() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        router.openHood(Self.makeHood(id: "florentin"))

        MapScreen.openSearch(router: router, chrome: chrome)

        #expect(router.hood == nil)
        #expect(chrome.presented == .search)
    }

    @Test("opening .search while .heat (or any other surface) is presented replaces it — chrome never stacks")
    func openSearchReplacesOtherSurface() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        chrome.toggle(.heat)

        MapScreen.openSearch(router: router, chrome: chrome)

        #expect(chrome.presented == .search)
    }

    // MARK: - §9 row 7: `dismissSearch` is a completion — clears the session

    @Test("dismissSearch clears text, filter, any open destination, and the surface")
    func dismissSearchClearsEverything() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        let session = SearchSession()
        session.text = "florentin"
        session.filter = .only(.eatDrink)
        chrome.toggle(.search)
        router.openHood(Self.makeHood(id: "florentin"))
        router.openPlace(Self.makePlace(id: "cafe"))

        MapScreen.dismissSearch(router: router, chrome: chrome, session: session)

        #expect(session.text.isEmpty)
        #expect(session.filter == .fresh)
        #expect(router.hood == nil)
        #expect(router.place == nil)
        #expect(chrome.presented == nil)
    }

    // MARK: - §9 row 1(d)/D11: leaving `.search` by any path calls closeHood()

    @Test("§4.9/D11: switching straight from .search to another surface closes a destination sheet search opened")
    func interruptingSearchClosesOpenDestination() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        chrome.toggle(.search)
        router.openHood(Self.makeHood(id: "florentin"))

        let oldValue = chrome.presented
        chrome.toggle(.heat)
        MapScreen.handlePresentedSurfaceChange(from: oldValue, to: chrome.presented, router: router)

        #expect(router.hood == nil)
        #expect(chrome.presented == .heat)
    }

    @Test("switching from .search to .places also closes a place opened from a search result")
    func interruptingSearchClosesOpenPlace() {
        let router = DetailRouter()
        router.openPlace(Self.makePlace(id: "cafe"))

        MapScreen.handlePresentedSurfaceChange(from: .search, to: .places, router: router)

        #expect(router.place == nil)
    }

    @Test("opening .search (nil -> .search) does not close an unrelated destination that predates it")
    func openingSearchDoesNotCloseUnrelatedDestination() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "florentin"))

        MapScreen.handlePresentedSurfaceChange(from: nil, to: .search, router: router)

        #expect(router.hood != nil)
    }

    @Test("a no-op surface change (.search -> .search) touches nothing")
    func noOpSurfaceChangeTouchesNothing() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "florentin"))

        MapScreen.handlePresentedSurfaceChange(from: .search, to: .search, router: router)

        #expect(router.hood != nil)
    }

    // MARK: - Regression: the `.places` behaviour `handlePresentedSurfaceChange` already had is unchanged

    @Test("regression: leaving .places still closes a stacked place modal, unaffected by the .search branch")
    func placesRegressionUnaffected() {
        let router = DetailRouter()
        router.openPlace(Self.makePlace(id: "cafe"))

        MapScreen.handlePresentedSurfaceChange(from: .places, to: .heat, router: router)

        #expect(router.place == nil)
    }
}
