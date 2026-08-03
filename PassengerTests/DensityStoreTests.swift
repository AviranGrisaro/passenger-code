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

/// Mirrors `PlaceCatalogTests`' `FetchSpy` — proves `load()` never reaches
/// the fetch call while `BuildPhase.seedIsAuthoritative` is `true` (C10).
private actor SpyDensityAPI: DensityFetching {
    private(set) var wasCalled = false
    func fetchDensity(from anchorHour: Date) async throws -> [DensityAPI.Row] {
        wasCalled = true
        return []
    }
}

/// Covers the T-032 seam's actual contract (TRD §4.4): `selectedHour` starts
/// at 0, `band(for:hour:)` never triggers a fetch, and `refreshIfHourRolled()`
/// preserves the user's chosen absolute hour across a wall-clock hour roll,
/// clamping to 0 only when that hour has genuinely rolled out of range.
///
/// **Deviation disclosed, not silent (TRD §4.5 item 1 / §3.4, C10).** The
/// three tests this file shipped with under T-031 — `liveLoadResolvesBand`,
/// `failedFetchNoCacheIsUnavailable`, `failedFetchWithCacheFallsBack` — each
/// asserted `load()`'s live-fetch/cache-fallback behaviour by injecting a
/// `FakeDensityAPI`/`FakeDensityCache` and reading `store.source` afterward.
/// T-032's C10 adds an unconditional `if BuildPhase.seedIsAuthoritative`
/// short-circuit at the top of `load()`, mirroring `PlaceCatalog.load()`
/// exactly, per the TRD's own instruction. `BuildPhase.seedIsAuthoritative`
/// is a bare global constant with no per-instance override — exactly like
/// `PlaceCatalog`'s identical check — so every one of those three tests now
/// resolves `.seed` instead of `.live`/`.unavailable`/`.cache`, regardless of
/// what the injected fakes were told to do. This is not a bug in the tests
/// or the build: `PlaceCatalogTests.swift` already carries this same
/// resolution for the identical shape of problem (its own header: "the
/// live/cache branches are built to spec... but deliberately not exercised
/// here"), and `PlaceCatalogTests`' `sourceIsSeedAfterLoad` /
/// `loadMakesZeroFetchAttempts` are the direct precedent for the two tests
/// below that replace the three removed ones. No unique coverage is lost —
/// `DensitySnapshot(rows:)`'s own parsing/boundary-validation logic (what
/// those three tests were actually exercising, one layer down) is fully
/// covered independently in `DensitySnapshotTests.swift`. Flagged for
/// `ios-code-reviewer`/`architect`: the TRD's §4.5 preamble asks that
/// T-031's existing tests "pass unmodified alongside the new cases," which
/// cannot hold in the literal sense once C10 is built exactly as specified —
/// this is that finding, not a workaround around it.
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

    // MARK: - C10: Build Phase 1 seed is authoritative (TRD §3.4, §4.5 item 1)

    @Test("load() reports .seed and resolves a real bundled band, per BuildPhase.seedIsAuthoritative")
    func seedIsAuthoritativeAfterLoad() async {
        let fixedNow = Self.date("2026-07-30T18:00:00Z")
        let store = DensityStore(api: FakeDensityAPI(rows: [], error: nil), cache: FakeDensityCache(), now: { fixedNow })

        await store.load()

        #expect(store.source == .seed)
        // `Resources/density-seed-tel-aviv.json`'s florentin entry, offset 0.
        #expect(store.band(for: "florentin", hour: 0) == .moderate)
    }

    @Test("load() makes zero fetch attempts while the seed is authoritative — a DensityFetching spy is never called")
    func loadMakesZeroFetchAttemptsWhileSeedIsAuthoritative() async {
        let spy = SpyDensityAPI()
        let store = DensityStore(api: spy, cache: FakeDensityCache())

        await store.load()

        #expect(await spy.wasCalled == false)
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

    // MARK: - C8: the mid-`await` guard (TRD §4.5 item 3)

    /// Exercises the guard deterministically with no real concurrency, by
    /// smuggling the "concurrent edit" into the injected `now()` closure —
    /// `load()`'s own first line calls `now()` again while
    /// `refreshIfHourRolled()` is suspended at `await load()`, which is
    /// exactly the window TRD §4.5 item 3 names. Call sequence: 1 = `init`,
    /// 2 = the initial `store.load()` below, 3 = `refreshIfHourRolled`'s own
    /// roll check, 4 = `load()`'s internal re-anchor from inside the await —
    /// mutating `selectedHour` there stands in for the user moving the
    /// slider or dragging an edge mid-refresh.
    @Test("refreshIfHourRolled does not clobber a selectedHour change that lands while load() is in flight")
    func refreshDoesNotClobberAConcurrentEdit() async {
        var current = Self.date("2026-07-30T18:00:00Z")
        var callCount = 0
        var store: DensityStore!
        store = DensityStore(
            api: FakeDensityAPI(rows: [], error: nil),
            cache: FakeDensityCache(),
            now: {
                callCount += 1
                if callCount == 4 {
                    store.selectedHour = 9
                }
                return current
            }
        )
        await store.load()
        store.selectedHour = 3
        current = current.addingTimeInterval(3600)

        await store.refreshIfHourRolled()

        // The remap that would have run against the captured value (3) is
        // skipped entirely — the "concurrent" write (9) stands untouched.
        #expect(store.selectedHour == 9)
    }
}
