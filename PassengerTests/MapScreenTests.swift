import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers `MapScreen.isNewGrant`, the predicate behind the recenter-on-grant
/// fix for qa's T-031 Finding A: the camera must recenter when authorization
/// transitions into an authorized state via the app's own auto-scheduled
/// system prompt, not only via a `NearMeButton` tap. This is a pure function
/// so it's tested directly rather than through `.onChange` plumbing.
@Suite("MapScreen.isNewGrant")
struct MapScreenTests {
    @Test("not determined -> authorized when in use is a new grant")
    func notDeterminedToAuthorizedWhenInUse() {
        #expect(MapScreen.isNewGrant(from: .notDetermined, to: .authorizedWhenInUse))
    }

    @Test("not determined -> authorized always is a new grant")
    func notDeterminedToAuthorizedAlways() {
        #expect(MapScreen.isNewGrant(from: .notDetermined, to: .authorizedAlways))
    }

    @Test("denied -> authorized when in use (Settings toggle) is a new grant")
    func deniedToAuthorized() {
        #expect(MapScreen.isNewGrant(from: .denied, to: .authorizedWhenInUse))
    }

    @Test("restricted -> authorized when in use is a new grant")
    func restrictedToAuthorized() {
        #expect(MapScreen.isNewGrant(from: .restricted, to: .authorizedWhenInUse))
    }

    @Test("authorized when in use -> authorized always is NOT a new grant")
    func lateralAuthorizedMoveIsNotNewGrant() {
        #expect(!MapScreen.isNewGrant(from: .authorizedWhenInUse, to: .authorizedAlways))
    }

    @Test("authorized always -> authorized when in use is NOT a new grant")
    func lateralAuthorizedMoveReverseIsNotNewGrant() {
        #expect(!MapScreen.isNewGrant(from: .authorizedAlways, to: .authorizedWhenInUse))
    }

    @Test("no-op status repeat is NOT a new grant")
    func sameStatusIsNotNewGrant() {
        #expect(!MapScreen.isNewGrant(from: .authorizedWhenInUse, to: .authorizedWhenInUse))
        #expect(!MapScreen.isNewGrant(from: .notDetermined, to: .notDetermined))
    }

    @Test("not determined -> denied is NOT a new grant")
    func notDeterminedToDeniedIsNotNewGrant() {
        #expect(!MapScreen.isNewGrant(from: .notDetermined, to: .denied))
    }

    @Test("authorized -> denied (revoked in Settings) is NOT a new grant")
    func revokedIsNotNewGrant() {
        #expect(!MapScreen.isNewGrant(from: .authorizedWhenInUse, to: .denied))
    }
}

/// Covers places-been-saved TRD §9 row 8(b)/(c) and D8's presentation
/// exclusivity — pure functions over `DetailRouter`/`MapChromeState`, same
/// construction as `isNewGrant` above, so the wiring is unit-tested directly
/// rather than through `.onChange`/button-tap plumbing that needs a live
/// SwiftUI environment.
@Suite("MapScreen D8 presentation wiring")
@MainActor
struct MapScreenD8WiringTests {
    @Test("§9 row 8(b): opening the Places list with a Hood sheet open closes the Hood sheet")
    func openPlacesListClosesHood() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10)]
        router.openHood(Hood(
            id: "florentin", name: "florentin", ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false
        ))

        MapScreen.openPlacesList(router: router, chrome: chrome)

        #expect(router.hood == nil)
        #expect(chrome.presented == .places)
    }

    @Test("§9 row 8(c): toggling to .heat while the list is open and a place modal is stacked closes both, .heat is presented")
    func leavingPlacesClosesStackedPlaceModal() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        chrome.toggle(.places)
        router.openPlace(Place(
            id: "cafe", name: "cafe", category: .eatDrink, hoodID: "florentin",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), permanentlyClosed: false,
            placeType: "cafe", isTouristTrap: nil
        ))

        let oldValue = chrome.presented
        chrome.toggle(.heat)
        MapScreen.handlePresentedSurfaceChange(from: oldValue, to: chrome.presented, router: router)

        #expect(router.place == nil)
        #expect(chrome.presented == .heat)
    }

    @Test("opening the list (nil -> .places) does not close an unrelated place modal")
    func openingPlacesDoesNotClosePlace() {
        let router = DetailRouter()
        router.openPlace(Place(
            id: "cafe", name: "cafe", category: .eatDrink, hoodID: "florentin",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), permanentlyClosed: false,
            placeType: "cafe", isTouristTrap: nil
        ))

        MapScreen.handlePresentedSurfaceChange(from: nil, to: .places, router: router)

        #expect(router.place != nil)
    }

    @Test("dismissing the list (.places -> nil) closes a stacked place modal")
    func dismissingPlacesClosesStackedPlaceModal() {
        let router = DetailRouter()
        router.openPlace(Place(
            id: "cafe", name: "cafe", category: .eatDrink, hoodID: "florentin",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), permanentlyClosed: false,
            placeType: "cafe", isTouristTrap: nil
        ))

        MapScreen.handlePresentedSurfaceChange(from: .places, to: nil, router: router)

        #expect(router.place == nil)
    }

    /// PAS-42 (2026-08-04): `PlacesButton` no longer fades to
    /// non-hit-testable while `.places` is open (it merged into the
    /// always-visible `MapNavRow`), so the "can't be re-tapped to dismiss
    /// its own list" protection D7 used to provide via invisibility now has
    /// to be a real guard in `openPlacesList` itself. This is that guard's
    /// only direct test — a re-tap while already open must be a true no-op,
    /// not a `chrome.toggle` that closes the list, and must not call
    /// `closeHood()` either (proven by leaving a Hood sheet open and
    /// asserting it's still there).
    @Test("PAS-42: re-tapping Places while its list is already open is a no-op")
    func reopeningPlacesWhileAlreadyOpenIsANoOp() {
        let router = DetailRouter()
        let chrome = MapChromeState()
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10)]
        chrome.toggle(.places)
        router.openHood(Hood(
            id: "florentin", name: "florentin", ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false
        ))

        MapScreen.openPlacesList(router: router, chrome: chrome)

        #expect(chrome.presented == .places, "a re-tap on an already-open list must not close it")
        #expect(router.hood != nil, "a re-tap on an already-open list must be a true no-op, not partially run closeHood()")
    }
}
