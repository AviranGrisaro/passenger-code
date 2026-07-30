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

    /// Once per session (§4.5). Falls back to the last-good cache, then to
    /// silent unavailability — never a crash, never a partial snapshot treated
    /// as complete.
    func load() async {
        anchorHour = Self.hourFloor(of: now())
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
                snapshot = .empty
                source = .unavailable
            }
        }
    }

    /// Called on `scenePhase → .active` (TRD §4.4). If the wall-clock hour has
    /// rolled since the snapshot was anchored, re-fetch and remap
    /// `selectedHour` so the *absolute* hour the user chose is preserved where
    /// it's still inside `[now, now+12]`, clamped to `0` otherwise.
    func refreshIfHourRolled() async {
        let newFloor = Self.hourFloor(of: now())
        guard newFloor != anchorHour else { return }

        let previousAbsoluteHour = Self.epochHour(for: anchorHour) + selectedHour
        await load()  // re-anchors `anchorHour` to `newFloor` internally
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
