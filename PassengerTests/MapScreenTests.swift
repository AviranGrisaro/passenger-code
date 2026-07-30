import CoreLocation
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
