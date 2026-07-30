import Foundation
import Testing
@testable import Passenger

private struct FakeDensityAPI: DensityFetching {
    let rows: [DensityAPI.Row]
    let error: Error?

    func fetchDensity(from anchorHour: Date) async throws -> [DensityAPI.Row] {
        if let error { throw error }
        return rows
    }
}

private actor FakeDensityCache: DensityCaching {
    private var stored: [DensityAPI.Row]?
    func save(rows: [DensityAPI.Row]) async { stored = rows }
    func loadIfPresent() async -> [DensityAPI.Row]? { stored }
}

private struct StubFetchError: Error {}

/// Covers the T-032 seam's actual contract (TRD §4.4): `selectedHour` starts
/// at 0, `band(for:hour:)` never triggers a fetch, and `refreshIfHourRolled()`
/// preserves the user's chosen absolute hour across a wall-clock hour roll,
/// clamping to 0 only when that hour has genuinely rolled out of range.
@Suite("DensityStore")
@MainActor
struct DensityStoreTests {
    private static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    @Test("selectedHour starts at 0 on cold launch")
    func startsAtZero() {
        let store = DensityStore(api: FakeDensityAPI(rows: [], error: nil), cache: FakeDensityCache())
        #expect(store.selectedHour == 0)
    }

    @Test("a successful load reports .live and resolves the fetched band")
    func liveLoadResolvesBand() async {
        let fixedNow = Self.date("2026-07-30T18:00:00Z")
        let row = DensityAPI.Row(hoodID: "florentin", hourBucket: "2026-07-30T18:00:00Z", band: 2)
        let store = DensityStore(api: FakeDensityAPI(rows: [row], error: nil), cache: FakeDensityCache(), now: { fixedNow })

        await store.load()

        #expect(store.source == .live)
        #expect(store.band(for: "florentin", hour: 0) == .moderate)
    }

    @Test("a failed fetch with no cache falls back to .unavailable, not a crash")
    func failedFetchNoCacheIsUnavailable() async {
        let store = DensityStore(api: FakeDensityAPI(rows: [], error: StubFetchError()), cache: FakeDensityCache())

        await store.load()

        #expect(store.source == .unavailable)
        #expect(store.band(for: "florentin", hour: 0) == nil)
    }

    @Test("a failed fetch with a cache falls back to .cache and still resolves bands")
    func failedFetchWithCacheFallsBack() async {
        let fixedNow = Self.date("2026-07-30T18:00:00Z")
        let cache = FakeDensityCache()
        await cache.save(rows: [DensityAPI.Row(hoodID: "florentin", hourBucket: "2026-07-30T18:00:00Z", band: 1)])
        let store = DensityStore(api: FakeDensityAPI(rows: [], error: StubFetchError()), cache: cache, now: { fixedNow })

        await store.load()

        #expect(store.source == .cache)
        #expect(store.band(for: "florentin", hour: 0) == .quiet)
    }

    @Test("refreshIfHourRolled preserves the absolute hour the user selected, when still in range")
    func refreshPreservesAbsoluteHour() async {
        var current = Self.date("2026-07-30T18:00:00Z")
        let store = DensityStore(api: FakeDensityAPI(rows: [], error: nil), cache: FakeDensityCache(), now: { current })
        await store.load()

        store.selectedHour = 3  // absolute hour 21:00
        current = current.addingTimeInterval(3600)  // wall clock rolls to 19:00
        await store.refreshIfHourRolled()

        #expect(store.selectedHour == 2)  // still 21:00, now 2 hours ahead of the new anchor
    }

    @Test("refreshIfHourRolled clamps to 0 once the selected hour has rolled out of range")
    func refreshClampsWhenOutOfRange() async {
        var current = Self.date("2026-07-30T18:00:00Z")
        let store = DensityStore(api: FakeDensityAPI(rows: [], error: nil), cache: FakeDensityCache(), now: { current })
        await store.load()

        store.selectedHour = 0  // absolute hour 18:00
        current = current.addingTimeInterval(3600)  // wall clock rolls past it, to 19:00
        await store.refreshIfHourRolled()

        #expect(store.selectedHour == 0)
    }

    @Test("refreshIfHourRolled is a no-op within the same wall-clock hour")
    func noRefreshWithinSameHour() async {
        let current = Self.date("2026-07-30T18:00:00Z")
        let store = DensityStore(api: FakeDensityAPI(rows: [], error: nil), cache: FakeDensityCache(), now: { current.addingTimeInterval(120) })
        await store.load()
        store.selectedHour = 5

        await store.refreshIfHourRolled()

        #expect(store.selectedHour == 5)
    }
}
