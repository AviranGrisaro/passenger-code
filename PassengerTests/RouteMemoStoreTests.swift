import CoreLocation
import Testing
@testable import Passenger

/// TRD §4.7, A2, §9 row 10/11(d).
@Suite("RouteMemoStore")
@MainActor
struct RouteMemoStoreTests {
    private static func fastPlan() -> RoutePlan {
        RoutePlan(kind: .fast, coordinates: [CLLocationCoordinate2D(latitude: 0, longitude: 0)], distance: 500, travelTime: 400, viaHoodName: nil)
    }

    private static func resolvedPreview() -> RoutePreview {
        .resolved(fast: fastPlan(), scenic: .failure(.noQualifyingHood))
    }

    @Test("a fresh store has no memo for any place")
    func freshStoreIsEmpty() {
        let store = RouteMemoStore()
        #expect(store.preview(for: "cafe") == nil)
    }

    @Test("a stored .resolved preview is returned before the TTL expires")
    func storedPreviewIsReturnedBeforeTTL() {
        let store = RouteMemoStore()
        let now = Date()
        store.store(Self.resolvedPreview(), for: "cafe", now: now)
        #expect(store.preview(for: "cafe", now: now.addingTimeInterval(299)) == Self.resolvedPreview())
    }

    @Test("a stored preview is nil once the TTL has passed")
    func storedPreviewExpiresAfterTTL() {
        let store = RouteMemoStore()
        let now = Date()
        store.store(Self.resolvedPreview(), for: "cafe", now: now)
        #expect(store.preview(for: "cafe", now: now.addingTimeInterval(301)) == nil)
    }

    @Test("only .resolved is memoised — .idle, .resolving, .noOrigin and .failed are all no-ops")
    func onlyResolvedIsMemoised() {
        let store = RouteMemoStore()
        store.store(.idle, for: "a")
        store.store(.resolving, for: "b")
        store.store(.noOrigin, for: "c")
        store.store(.failed, for: "d")
        #expect(store.preview(for: "a") == nil)
        #expect(store.preview(for: "b") == nil)
        #expect(store.preview(for: "c") == nil)
        #expect(store.preview(for: "d") == nil)
    }

    @Test("the memo is keyed on Place.id alone, not on any coordinate — two different places never collide")
    func keyedOnPlaceIDAlone() {
        let store = RouteMemoStore()
        store.store(Self.resolvedPreview(), for: "cafe-a")
        #expect(store.preview(for: "cafe-a") != nil)
        #expect(store.preview(for: "cafe-b") == nil)
    }

    @Test("clearAll drops every entry regardless of TTL")
    func clearAllDropsEverything() {
        let store = RouteMemoStore()
        store.store(Self.resolvedPreview(), for: "cafe")
        store.clearAll()
        #expect(store.preview(for: "cafe") == nil)
    }
}
