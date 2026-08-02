import Foundation
import Testing
@testable import Passenger

private actor FetchSpy: EventsFetching {
    private(set) var wasCalled = false

    func fetchEvents(anchorHour: Date) async throws -> [EventsAPI.Row] {
        wasCalled = true
        return []
    }
}

/// Covers T-034 TRD §3.4.1-equivalent Build-Phase-1 determinism (mirrors
/// `PlaceCatalogTests`' own three assertions), plus `refresh`'s no-op guard
/// (§4.6) at the decision-logic level. The live-fetch branch (D8: never
/// falls back to the seed) is built to spec but, like `PlaceCatalog`'s own
/// live/cache branches, deliberately not exercised here while
/// `BuildPhase.eventSeedIsAuthoritative` is `true` — `LiveEvent.init(row:)`'s
/// own boundary validation is covered separately in `EventsAPITests`.
@Suite("EventStore")
@MainActor
struct EventStoreTests {
    @Test("after load(), source is .seed — Build Phase 1's authoritative branch")
    func sourceIsSeedAfterLoad() async {
        let store = EventStore()
        await store.load(anchorHour: Date())
        #expect(store.source == .seed)
    }

    @Test("load() makes zero fetch attempts in Build Phase 1")
    func loadMakesZeroFetchAttempts() async {
        let spy = FetchSpy()
        let store = EventStore(api: spy)
        await store.load(anchorHour: Date())
        #expect(await spy.wasCalled == false)
    }

    @Test("a missing bundled seed resource reports .unavailable, never a crash, never a hollow .seed claim")
    func missingSeedResourceIsUnavailable() async {
        let store = EventStore(seedResourceName: "does-not-exist")
        await store.load(anchorHour: Date())
        #expect(store.source == .unavailable)
        #expect(store.events.isEmpty)
    }

    @Test("isLayerVisible defaults true — the layer ships on (PRD req 6)")
    func layerVisibleDefaultsTrue() {
        let store = EventStore()
        #expect(store.isLayerVisible)
    }

    @Test("seed events resolve against the anchorHour passed to load(), not a fixed clock")
    func seedEventsResolveAgainstPassedAnchor() async throws {
        let store = EventStore(seedResourceName: "events-test-fixture", bundle: Self.testBundle)
        let anchor = ISO8601DateFormatter().date(from: "2026-08-03T10:00:00Z")!
        await store.load(anchorHour: anchor)

        // "fixture-normal" is `start_offset_minutes: 60` — its `startAt`
        // must be exactly one hour after *this* anchor, proving the offset
        // was resolved against the argument, not a wall-clock read.
        let normal = try #require(store.events.first { $0.id == "fixture-normal" })
        #expect(normal.startAt == anchor.addingTimeInterval(60 * 60))
    }

    // MARK: - refresh's no-op guard (§4.6) — tested at the decision-logic
    // level so it doesn't depend on forcing either branch of `load` to run.

    @Test("shouldReload is true the first time (no prior anchor)")
    func shouldReloadFirstTime() {
        let anchor = Date()
        #expect(EventStore.shouldReload(loadedAnchorHour: nil, requestedAnchorHour: anchor))
    }

    @Test("shouldReload is false when the anchor hasn't changed — no second request on a double foreground")
    func shouldReloadFalseWhenUnchanged() {
        let anchor = Date()
        #expect(!EventStore.shouldReload(loadedAnchorHour: anchor, requestedAnchorHour: anchor))
    }

    @Test("shouldReload is true when the hour actually rolled")
    func shouldReloadTrueWhenChanged() {
        let first = Date()
        let second = first.addingTimeInterval(3600)
        #expect(EventStore.shouldReload(loadedAnchorHour: first, requestedAnchorHour: second))
    }

    @Test("refresh() is a genuine no-op when the anchor is unchanged — events stay stable across two refreshes")
    func refreshIsNoOpForSameAnchor() async {
        let store = EventStore(seedResourceName: "events-test-fixture", bundle: Self.testBundle)
        let anchor = ISO8601DateFormatter().date(from: "2026-08-03T10:00:00Z")!
        await store.load(anchorHour: anchor)
        let eventsAfterLoad = store.events

        await store.refresh(anchorHour: anchor)
        #expect(store.events.map(\.id) == eventsAfterLoad.map(\.id))
    }

    @Test("refresh() reloads when the anchor actually changed")
    func refreshReloadsForChangedAnchor() async {
        let store = EventStore(seedResourceName: "events-test-fixture", bundle: Self.testBundle)
        let firstAnchor = ISO8601DateFormatter().date(from: "2026-08-03T10:00:00Z")!
        let secondAnchor = firstAnchor.addingTimeInterval(3600)

        await store.load(anchorHour: firstAnchor)
        let normalStart = store.events.first { $0.id == "fixture-normal" }?.startAt

        await store.refresh(anchorHour: secondAnchor)
        let reloadedStart = store.events.first { $0.id == "fixture-normal" }?.startAt

        #expect(normalStart != nil)
        #expect(reloadedStart != nil)
        #expect(normalStart != reloadedStart)  // resolved against the new anchor, not stale
    }

    // MARK: - Fixture bundle

    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }
}
