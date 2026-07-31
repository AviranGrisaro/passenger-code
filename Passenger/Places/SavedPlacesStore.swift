import Foundation

/// Device-local, per-place, durable saved state (TRD §3.5, §4.4). No view may
/// hold its own copy of this — a button must render `isSaved(_:)` directly
/// off this store, never a local `@State` mirror, so a load that resolves
/// after a modal is already on screen re-renders correctly instead of lying.
@MainActor
@Observable
final class SavedPlacesStore {
    private var savedIDs: Set<Place.ID> = []
    private let persistence: any SavedPlacesPersisting
    /// Monotonically increasing, so a reordered pair of fire-and-forget
    /// writes can never land the older set last (TRD §4.4).
    private var generation = 0

    init(persistence: any SavedPlacesPersisting = SavedPlacesPersistence()) {
        self.persistence = persistence
    }

    func isSaved(_ id: Place.ID) -> Bool {
        savedIDs.contains(id)
    }

    /// Instant in memory — the 400ms budget is met by construction because
    /// nothing here `await`s. Disk persistence is fire-and-forget (TRD §4.4).
    func toggle(_ id: Place.ID) {
        if savedIDs.contains(id) {
            savedIDs.remove(id)
        } else {
            savedIDs.insert(id)
        }
        generation += 1
        let snapshot = savedIDs
        let thisGeneration = generation
        Task { await persistence.save(ids: snapshot, generation: thisGeneration) }
    }

    /// Once per session, on `MapScreen`'s `.task` alongside `PlaceCatalog.load()`.
    /// A missing file is a valid first-launch state — `savedIDs` simply stays
    /// empty, never a crash.
    func load() async {
        if let loaded = await persistence.loadIfPresent() {
            savedIDs = loaded
        }
    }
}

/// Seam so `SavedPlacesStore` can be tested without touching disk — mirrors
/// `DensityCaching`/`PlacesCaching`.
protocol SavedPlacesPersisting: Sendable {
    func save(ids: Set<Place.ID>, generation: Int) async
    func loadIfPresent() async -> Set<Place.ID>?
}

/// `saved-places.json` in Application Support — a payload, not a preference
/// (TRD §3.5). Contains only place slugs: no coordinates, no timestamps, no
/// location of any kind — the minimal shape is the mitigation for the one
/// artifact in this feature that could plausibly leak where somebody goes.
actor SavedPlacesPersistence: SavedPlacesPersisting {
    private struct Payload: Codable {
        let ids: [String]
    }

    private let fileURL: URL
    /// The generation guard (TRD §4.4): a write carrying a generation at or
    /// below the last one actually written is stale and dropped, so two fast
    /// taps can never persist the wrong final state.
    private var lastWrittenGeneration = -1

    /// `fileURL` override exists for test isolation only (Swift Testing runs
    /// tests concurrently by default, and every production caller shares one
    /// real file — `SavedPlacesPersistenceTests` needs a private path per
    /// test so two tests writing at once can't race the same file).
    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = dir.appendingPathComponent("saved-places.json")
        }
    }

    func save(ids: Set<Place.ID>, generation: Int) async {
        guard generation > lastWrittenGeneration else { return }
        lastWrittenGeneration = generation
        let payload = Payload(ids: Array(ids))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    func loadIfPresent() async -> Set<Place.ID>? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return Set(payload.ids)
    }
}
