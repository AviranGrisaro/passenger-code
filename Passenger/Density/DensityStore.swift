import Foundation

/// The T-032 seam (TRD §4.4): `selectedHour` is a plain `Int` offset on an
/// `@Observable` class, no wrapper type, no publisher — confirmed shape before
/// either T-031 or T-032 built against it. `band(for:hour:)` is a dictionary
/// read against already-fetched data; no code path fetches on an hour change,
/// which is what makes T-032's 400ms repaint budget real.
///
/// Session-scoped and in-memory. `selectedHour` is never written to
/// `UserDefaults`/`AppStorage` — cold launch always starts at `0`.
@MainActor
@Observable
final class DensityStore {
    enum Source: Sendable {
        case live
        case cache
        /// Build Phase 1 (TRD §3.4, §8 D10) — the bundled, relative density
        /// seed. Also the final fallback below `.cache` once Phase 2 flips
        /// `BuildPhase.seedIsAuthoritative` to `false` (§4.5 item 1).
        case seed
        case unavailable
    }

    /// UTC hour floor the current snapshot is anchored to.
    private(set) var anchorHour: Date
    /// 0...12 offset from `anchorHour`. T-032's slider is the only writer.
    var selectedHour: Int = 0
    private(set) var source: Source = .unavailable

    private var snapshot: DensitySnapshot = .empty
    private let api: any DensityFetching
    private let cache: any DensityCaching
    // Not `@Sendable`: this class is itself `@MainActor`-isolated, and `now`
    // is only ever read from `load()`/`refreshIfHourRolled()`, both confined
    // to the main actor — no cross-actor call ever touches it. Testable via
    // injection (`DensityStoreTests`) without requiring the closure to be
    // safe to hand across actors, which it doesn't need to be.
    private let now: () -> Date

    init(
        api: any DensityFetching = DensityAPI(),
        cache: any DensityCaching = DensityCache(),
        now: @escaping () -> Date = Date.init
    ) {
        self.api = api
        self.cache = cache
        self.now = now
        self.anchorHour = Self.hourFloor(of: now())
    }

    /// `nil` == no data (PRD req 7) — never a default band.
    func band(for hoodID: String, hour: Int) -> HeatBand? {
        let epochHour = Self.epochHour(for: anchorHour) + hour
        return snapshot.band(for: hoodID, epochHour: epochHour)
    }

    /// Once per session (§4.5). **Build Phase 1 (TRD §3.4, §8 D10):**
    /// `BuildPhase.seedIsAuthoritative` pins the bundled, relative
    /// `DensitySeed` as authoritative — this branch attempts no fetch at
    /// all, deterministically, mirroring `PlaceCatalog.load()` exactly.
    ///
    /// Otherwise, the live → cache → **seed** → unavailable precedence:
    /// falls back to the last-good cache, then — new at T-032 — to the same
    /// bundled seed as a final fallback below cache, then to silent
    /// unavailability. Never a crash, never a partial snapshot treated as
    /// complete.
    func load() async {
        anchorHour = Self.hourFloor(of: now())

        if BuildPhase.seedIsAuthoritative {
            snapshot = DensitySnapshot(rows: DensitySeed.rows(anchorHour: anchorHour))
            source = .seed
            return
        }

        do {
            let rows = try await api.fetchDensity(from: anchorHour)
            snapshot = DensitySnapshot(rows: rows)
            source = .live
            await cache.save(rows: rows)
        } catch {
            if let cachedRows = await cache.loadIfPresent() {
                snapshot = DensitySnapshot(rows: cachedRows)
                source = .cache
            } else {
                let seedRows = DensitySeed.rows(anchorHour: anchorHour)
                if seedRows.isEmpty {
                    snapshot = .empty
                    source = .unavailable
                } else {
                    snapshot = DensitySnapshot(rows: seedRows)
                    source = .seed
                }
            }
        }
    }

    /// Called on `scenePhase → .active`, on heat-modal open, and on edge
    /// touch-down (TRD §4.4, §4.5 item 2 — the last two call sites are new
    /// at T-032, `HeatModalCard`/`EdgeHourZone`). If the wall-clock hour has
    /// rolled since the snapshot was anchored, re-fetch and remap
    /// `selectedHour` so the *absolute* hour the user chose is preserved where
    /// it's still inside `[now, now+12]`, clamped to `0` otherwise.
    func refreshIfHourRolled() async {
        let newFloor = Self.hourFloor(of: now())
        guard newFloor != anchorHour else { return }

        // Captured before the `await` below so the mid-await guard (TRD
        // §4.5 item 3) has something to compare against afterward.
        let capturedHour = selectedHour
        let previousAbsoluteHour = Self.epochHour(for: anchorHour) + capturedHour
        await load()  // re-anchors `anchorHour` to `newFloor` internally

        // Mid-`await` guard: if the user moved the slider or dragged an edge
        // while `load()` was in flight, `selectedHour` no longer matches
        // what this remap was computed from — leave their value alone
        // rather than clobbering it with a stale remap (TRD §4.5 item 3).
        guard selectedHour == capturedHour else { return }

        let newOffset = previousAbsoluteHour - Self.epochHour(for: anchorHour)
        selectedHour = (0...12).contains(newOffset) ? newOffset : 0
    }

    private static func hourFloor(of date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: components) ?? date
    }

    private static func epochHour(for date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 3600)
    }
}
