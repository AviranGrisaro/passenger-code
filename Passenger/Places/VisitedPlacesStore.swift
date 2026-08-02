import Foundation

/// Seam so `VisitedPlacesStore` can be tested against a fake and so Phase 2
/// can swap in the shared dwell detector's store with no other change (TRD
/// §4.2, §7). Mirrors `PlacesFetching`/`PlacesCaching`/`SavedPlacesPersisting`.
protocol VisitSourcing: Sendable {
    func loadVisits() async -> [Place.ID: VisitKind]
}

/// Been/Visited (TRD §3.1, §3.4). No persistence, no `CoreLocation` import —
/// deliberately, because a Been/Visited set is location history and Build
/// Phase 1 is the cheapest moment to fix its shape as "there isn't one yet."
/// Read-only: nothing in this feature writes to this store.
@MainActor
@Observable
final class VisitedPlacesStore {
    private(set) var visits: [Place.ID: VisitKind] = [:]
    private let source: any VisitSourcing

    init(source: any VisitSourcing = BundledVisitSource()) {
        self.source = source
    }

    /// Once per session, on `MapScreen`'s `.task`, alongside the other four
    /// loads. A missing or malformed fixture is an empty dictionary, never a
    /// crash — same posture as `PlaceCatalog.loadFromBundledSeed()`.
    func load() async {
        visits = await source.loadVisits()
    }
}
