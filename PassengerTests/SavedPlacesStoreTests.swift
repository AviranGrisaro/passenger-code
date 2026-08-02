import Foundation
import Testing
@testable import Passenger

private actor FakeSavedPlacesPersistence: SavedPlacesPersisting {
    private var stored: Set<Place.ID>?
    func save(ids: Set<Place.ID>, generation: Int) async { stored = ids }
    func loadIfPresent() async -> Set<Place.ID>? { stored }
}

/// Covers TRD §4.4/§3.5: `isSaved`/`toggle` are instant in memory, `load()`
/// tolerates a missing file, and the persistence actor's generation counter
/// (`SavedPlacesPersistence`) rejects a reordered stale write.
@Suite("SavedPlacesStore")
@MainActor
struct SavedPlacesStoreTests {
    @Test("a place starts unsaved")
    func startsUnsaved() {
        let store = SavedPlacesStore(persistence: FakeSavedPlacesPersistence())
        #expect(!store.isSaved("florentin-cafe"))
    }

    @Test("toggle is instant in memory — no await needed to observe it")
    func toggleIsInstant() {
        let store = SavedPlacesStore(persistence: FakeSavedPlacesPersistence())
        store.toggle("florentin-cafe")
        #expect(store.isSaved("florentin-cafe"))
        store.toggle("florentin-cafe")
        #expect(!store.isSaved("florentin-cafe"))
    }

    @Test("load() with no persisted file leaves every place unsaved, not a crash")
    func loadWithNoFileIsEmpty() async {
        let store = SavedPlacesStore(persistence: FakeSavedPlacesPersistence())
        await store.load()
        #expect(!store.isSaved("florentin-cafe"))
    }

    @Test("load() restores a previously persisted saved set")
    func loadRestoresPersistedSet() async {
        let persistence = FakeSavedPlacesPersistence()
        await persistence.save(ids: ["florentin-cafe"], generation: 1)
        let store = SavedPlacesStore(persistence: persistence)

        await store.load()

        #expect(store.isSaved("florentin-cafe"))
    }

    // MARK: - places-been-saved TRD §4.2 — the one addition to this store

    @Test("savedPlaceIDs mirrors isSaved(_:) exactly, with no new plumbing")
    func savedPlaceIDsMirrorsIsSaved() {
        let store = SavedPlacesStore(persistence: FakeSavedPlacesPersistence())
        #expect(store.savedPlaceIDs.isEmpty)

        store.toggle("florentin-cafe")
        #expect(store.savedPlaceIDs == ["florentin-cafe"])
        #expect(store.isSaved("florentin-cafe"))

        store.toggle("florentin-cafe")
        #expect(store.savedPlaceIDs.isEmpty)
    }
}

/// `SavedPlacesPersistence` tested directly (not through the store) so the
/// reordered-write guarantee is deterministic rather than racing real
/// `Task` scheduling (TRD §4.4). Each test gets its own temp file — Swift
/// Testing runs tests concurrently by default, and the production default
/// path is one shared file, so two tests hitting the real disk-backed actor
/// without their own path would race each other's writes.
@Suite("SavedPlacesPersistence")
struct SavedPlacesPersistenceTests {
    private static func makeIsolatedPersistence() -> SavedPlacesPersistence {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        return SavedPlacesPersistence(fileURL: fileURL)
    }

    @Test("a later generation's write always wins, even if it lands first")
    func laterGenerationWinsWhenItLandsFirst() async {
        let persistence = Self.makeIsolatedPersistence()
        await persistence.save(ids: ["b"], generation: 2)  // "latest" write lands first
        await persistence.save(ids: ["a"], generation: 1)  // stale write arrives after

        let result = await persistence.loadIfPresent()

        #expect(result == ["b"])
    }

    @Test("an in-order pair of writes persists the second one")
    func inOrderWritesPersistTheLast() async {
        let persistence = Self.makeIsolatedPersistence()
        await persistence.save(ids: ["a"], generation: 1)
        await persistence.save(ids: ["a", "b"], generation: 2)

        let result = await persistence.loadIfPresent()

        #expect(result == ["a", "b"])
    }
}
