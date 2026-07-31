import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers TRD §4.1: the depth ceiling never exceeds 2, `openHood` clears
/// `place`, `openPlace` preserves `hood`, both verbs are idempotent, and the
/// two-way bindings' dismiss path (`§4.1`, folded in at `trd-review`, finding
/// 2 in §8 D9) clears exactly the field the design spec's "one level up"
/// rule requires.
@Suite("DetailRouter")
@MainActor
struct DetailRouterTests {
    private static func makeHood(id: String) -> Hood {
        let ring = [
            MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0),
            MKMapPoint(x: 10, y: 10), MKMapPoint(x: 0, y: 10),
        ]
        return Hood(
            id: id, name: id, ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false
        )
    }

    private static func makePlace(id: String, hoodID: String) -> Place {
        Place(id: id, name: id, category: .eatDrink, hoodID: hoodID, coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    }

    @Test("starts with no modal open, placeDepth nil")
    func startsClosed() {
        let router = DetailRouter()
        #expect(router.placeDepth == nil)
        #expect(!router.isDepth1Presented.wrappedValue)
        #expect(!router.isDepth2Presented.wrappedValue)
    }

    @Test("openHood presents depth 1, not depth 2")
    func openHoodIsDepth1() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "florentin"))
        #expect(router.placeDepth == nil)
        #expect(router.isDepth1Presented.wrappedValue)
        #expect(!router.isDepth2Presented.wrappedValue)
    }

    @Test("openPlace directly from the map presents depth 1")
    func openPlaceFromMapIsDepth1() {
        let router = DetailRouter()
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))
        #expect(router.placeDepth == 1)
        #expect(router.isDepth1Presented.wrappedValue)
        #expect(!router.isDepth2Presented.wrappedValue)
    }

    @Test("openPlace while a Hood is open presents depth 2, never exceeding it")
    func openPlaceInsideHoodIsDepth2() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "florentin"))
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))
        #expect(router.placeDepth == 2)
        #expect(router.isDepth1Presented.wrappedValue)
        #expect(router.isDepth2Presented.wrappedValue)
    }

    @Test("openPlace never clears hood — a pin tap while the Hood sheet is open lands at depth 2")
    func openPlacePreservesHood() {
        let router = DetailRouter()
        let hood = Self.makeHood(id: "florentin")
        router.openHood(hood)
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))
        #expect(router.hood == hood)
    }

    @Test("openHood clears place — tapping a different Hood swaps the depth-1 destination")
    func openHoodClearsPlace() {
        let router = DetailRouter()
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))
        router.openHood(Self.makeHood(id: "neve-tzedek"))
        #expect(router.place == nil)
        #expect(router.placeDepth == nil)
    }

    @Test("openHood is idempotent for the same value when no place is open")
    func openHoodIdempotentForSameValue() {
        // `openHood` unconditionally clears `place` (TRD §4.1's own
        // pseudocode: `hood = hood; place = nil`) — that's true even when
        // re-opening the *same* Hood, since a caller can't distinguish "same
        // Hood" from "different Hood" without extra state this router
        // deliberately doesn't keep. The idempotency this covers is the
        // no-op case: nothing changes when there was no place to clear.
        let router = DetailRouter()
        let hood = Self.makeHood(id: "florentin")
        router.openHood(hood)
        router.openHood(hood)
        #expect(router.hood == hood)
        #expect(router.place == nil)
    }

    @Test("openPlace is idempotent for the same value — repeat calls don't change depth")
    func openPlaceIdempotentForSameValue() {
        // TRD §4.5 depends on this: the pin annotation's own `Button` and the
        // map's `SpatialTapGesture` can both fire for one physical tap, both
        // calling `openPlace` with the same place — the second call must be
        // a safe no-op, not a state change.
        let router = DetailRouter()
        let place = Self.makePlace(id: "cafe", hoodID: "florentin")
        router.openHood(Self.makeHood(id: "florentin"))
        router.openPlace(place)
        router.openPlace(place)
        #expect(router.place == place)
        #expect(router.placeDepth == 2)
    }

    @Test("closePlace clears only the place, leaving the Hood sheet standing")
    func closePlaceLeavesHoodStanding() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "florentin"))
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))
        router.closePlace()
        #expect(router.hood != nil)
        #expect(router.place == nil)
        #expect(router.placeDepth == nil)
    }

    @Test("closeHood clears both fields")
    func closeHoodClearsBoth() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "florentin"))
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))
        router.closeHood()
        #expect(router.hood == nil)
        #expect(router.place == nil)
    }

    @Test("no call sequence produces a depth greater than 2")
    func depthNeverExceedsTwo() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "a"))
        router.openPlace(Self.makePlace(id: "p1", hoodID: "a"))
        router.openPlace(Self.makePlace(id: "p2", hoodID: "a"))  // swap at depth 2
        router.openHood(Self.makeHood(id: "b"))                  // swap depth-1 destination
        router.openPlace(Self.makePlace(id: "p3", hoodID: "b"))
        #expect((router.placeDepth ?? 0) <= 2)
    }

    // MARK: - Dismiss path (two-way bindings, §4.1 / §8 D9 finding 2)

    @Test("writing false to isDepth2Presented clears the place only")
    func depth2BindingDismissClearsPlaceOnly() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "florentin"))
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))

        router.isDepth2Presented.wrappedValue = false

        #expect(router.hood != nil)
        #expect(router.place == nil)
        #expect(!router.isDepth2Presented.wrappedValue)
        #expect(router.isDepth1Presented.wrappedValue)
    }

    @Test("writing false to isDepth1Presented clears both fields")
    func depth1BindingDismissClearsBoth() {
        let router = DetailRouter()
        router.openHood(Self.makeHood(id: "florentin"))
        router.openPlace(Self.makePlace(id: "cafe", hoodID: "florentin"))

        router.isDepth1Presented.wrappedValue = false

        #expect(router.hood == nil)
        #expect(router.place == nil)
        #expect(!router.isDepth1Presented.wrappedValue)
        #expect(!router.isDepth2Presented.wrappedValue)
    }

    @Test("writing true to either binding is a no-op — there is nothing to default-open")
    func writingTrueIsIgnored() {
        let router = DetailRouter()
        router.isDepth1Presented.wrappedValue = true
        router.isDepth2Presented.wrappedValue = true
        #expect(router.hood == nil)
        #expect(router.place == nil)
        #expect(!router.isDepth1Presented.wrappedValue)
    }
}
