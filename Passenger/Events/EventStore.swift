import Foundation

/// Session-scoped, in-memory (§3.2, D8). No `UserDefaults`, no disk cache —
/// an events cache would be mostly expired by the time it's read, and once
/// `BuildPhase.eventSeedIsAuthoritative` is `false` the seed is never a
/// fallback: precedence is `live → empty`, not `live → seed → empty` (§7,
/// D8). A stale place is still a real place; a fabricated event beside real
/// data is a lie about tonight.
@MainActor
@Observable
final class EventStore {
    enum Source: Sendable {
        case live
        case seed
        case unavailable
    }

    private(set) var source: Source = .unavailable
    /// The whole loaded window, unfiltered — `EventSelection.selected` does
    /// the per-render-pass filtering (§4.4). `MapScreen` never reads this
    /// directly for drawing.
    private(set) var events: [LiveEvent] = []
    /// PRD req 6. Session-scoped, in memory, default `true` — the layer
    /// ships on. No `@State` mirror anywhere; this is the one storage
    /// location (§4.8).
    var isLayerVisible: Bool = true

    private let api: any EventsFetching
    private let seedResourceName: String
    private let bundle: Bundle
    /// The anchor hour `events` was last loaded for. `refresh` no-ops when
    /// this hasn't changed, so an app foregrounded twice inside one hour
    /// makes no second request (§4.6) — `shouldReload` is the pure decision
    /// this guards with, tested directly without needing to force either of
    /// `load`'s two branches.
    private var loadedAnchorHour: Date?

    init(
        api: any EventsFetching = EventsAPI(),
        seedResourceName: String = "events-tel-aviv-seed",
        bundle: Bundle = .main
    ) {
        self.api = api
        self.seedResourceName = seedResourceName
        self.bundle = bundle
    }

    /// Once per session (§4.6, mirrors `DensityStore.load()`/`PlaceCatalog.load()`).
    ///
    /// Phase 1 (`BuildPhase.eventSeedIsAuthoritative == true`): resolves the
    /// bundled seed against `anchorHour` and attempts no fetch at all. A
    /// missing/malformed bundled resource reports `.unavailable` rather than
    /// claiming `.seed` over an empty catalog — same rule `PlaceCatalog`'s
    /// bundled-seed path holds.
    ///
    /// Phase 3 (constant `false`, built and unexercised until then): live
    /// fetch only. A throw degrades straight to an honest empty layer —
    /// never to the seed (D8) — because req 5 blesses an absent layer as a
    /// shippable state and a fabricated event beside real places is not.
    func load(anchorHour: Date) async {
        loadedAnchorHour = anchorHour

        if BuildPhase.eventSeedIsAuthoritative {
            if let seeded = try? EventSeed.events(anchorHour: anchorHour, resourceName: seedResourceName, bundle: bundle) {
                events = seeded
                source = .seed
            } else {
                events = []
                source = .unavailable
            }
            return
        }

        do {
            let rows = try await api.fetchEvents(anchorHour: anchorHour)
            events = rows.compactMap(LiveEvent.init(row:))
            source = .live
        } catch {
            events = []
            source = .unavailable
        }
    }

    /// Called on `scenePhase → .active`, reusing `densityStore.anchorHour` as
    /// the "did the hour roll" signal (§4.6) rather than a second timer or a
    /// duplicated hour store (D12) — a no-op unless `anchorHour` actually
    /// differs from what's loaded.
    func refresh(anchorHour: Date) async {
        guard Self.shouldReload(loadedAnchorHour: loadedAnchorHour, requestedAnchorHour: anchorHour) else { return }
        await load(anchorHour: anchorHour)
    }

    /// Pure decision behind `refresh` — `internal` (not `private`) purely so
    /// it's directly unit-testable without needing to force either branch of
    /// `load` to run twice.
    static func shouldReload(loadedAnchorHour: Date?, requestedAnchorHour: Date) -> Bool {
        loadedAnchorHour != requestedAnchorHour
    }
}
