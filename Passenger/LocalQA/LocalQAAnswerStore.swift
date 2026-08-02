import Foundation

/// One answered place (TRD §3.3). A place slug only — never a coordinate,
/// even though the coordinate is already in the bundle; storing it again in
/// a per-user file would add nothing and leak more.
struct LocalQARecord: Codable, Sendable, Equatable {
    let placeID: String
    let answer: Bool
    /// Truncated to the UTC hour (TRD §3.3) — hour precision is all the
    /// eventual signal needs; minute precision would be a movement log.
    let answeredAtHour: Date
}

/// The whole on-disk shape of `local-qa.json` (TRD §3.3).
struct LocalQAFile: Codable, Sendable {
    let installID: LocalQAInstallIdentity
    /// For the cadence cap only (TRD §8 D8) — a separate clock from
    /// `records`, so an ignored toast is neither silently permanent (if it
    /// shared the answer clock) nor silently free (if it shared none).
    let lastAskedAt: Date?
    let records: [LocalQARecord]
}

/// In-memory ledger + queue + `lastAskedAt`, device-local (TRD §3.3, §4.3).
/// Same shape as `SavedPlacesStore`: instant in memory, disk persistence is
/// fire-and-forget with a generation guard against a reordered write.
@MainActor
@Observable
final class LocalQAAnswerStore {
    private(set) var installID: LocalQAInstallIdentity
    private(set) var answeredPlaceIDs: Set<Place.ID> = []
    private(set) var lastAskedAt: Date?
    /// Records not yet accepted by `LocalQASyncing.flush` (TRD §4.3) —
    /// grows while sync is disabled/offline; Phase 1 never drains it
    /// (`DisabledLocalQASync` accepts nothing).
    private(set) var pendingQueue: [LocalQARecord] = []

    private let persistence: any LocalQAPersisting
    private var generation = 0

    init(persistence: any LocalQAPersisting = LocalQAPersistence()) {
        self.persistence = persistence
        // Replaced by `load()` if a file already exists; a fresh install
        // needs an id from first write, not just from first load.
        self.installID = .generate()
    }

    /// Once per session, alongside the other stores' `.task` loads
    /// (`MapScreen`). A missing or corrupt file degrades to the same
    /// in-memory defaults set at `init` — never a crash (TRD §7).
    func load() async {
        guard let file = await persistence.loadIfPresent() else { return }
        installID = file.installID
        lastAskedAt = file.lastAskedAt
        answeredPlaceIDs = Set(file.records.map(\.placeID))
        pendingQueue = file.records
    }

    /// Written on every `.offer` (D8), regardless of whether the toast is
    /// ever answered — so the daily cap applies even to an ignored ask.
    func recordOffer(now: Date) {
        lastAskedAt = now
        persist()
    }

    /// Yes/No (TRD §5). Instant in memory; disk persistence is
    /// fire-and-forget with the same generation guard `SavedPlacesStore`
    /// uses. An answer is recorded even when it agrees with the flag's
    /// current value (req 9) — this store never reads the flag to compare.
    func record(placeID: Place.ID, answer: Bool, at date: Date) {
        let record = LocalQARecord(placeID: placeID, answer: answer, answeredAtHour: Self.hourFloor(of: date))
        answeredPlaceIDs.insert(placeID)
        pendingQueue.append(record)
        persist()
    }

    private func persist() {
        generation += 1
        let snapshot = LocalQAFile(installID: installID, lastAskedAt: lastAskedAt, records: pendingQueue)
        let thisGeneration = generation
        Task { await persistence.save(snapshot, generation: thisGeneration) }
    }

    private static func hourFloor(of date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: components) ?? date
    }
}

/// Seam so `LocalQAAnswerStore` can be tested without touching disk —
/// mirrors `SavedPlacesPersisting`.
protocol LocalQAPersisting: Sendable {
    func save(_ file: LocalQAFile, generation: Int) async
    func loadIfPresent() async -> LocalQAFile?
}

/// `local-qa.json` in Application Support (TRD §3.3). Stronger handling than
/// `SavedPlacesPersistence` on purpose: this file records that a person was
/// *physically present* at a named place at a time, not merely an intent.
/// Excluded from device backup and written with
/// `.completeUntilFirstUserAuthentication` file protection — both build
/// steps, not principles.
actor LocalQAPersistence: LocalQAPersisting {
    private let fileURL: URL
    /// Monotonically increasing (TRD §4.3): a reordered pair of
    /// fire-and-forget writes can never land the older state last.
    private var lastWrittenGeneration = -1

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = dir.appendingPathComponent("local-qa.json")
        }

        // UI-test-only reset (mirrors `MapScreen`'s `-uiTestZoomedIn`
        // precedent): a real launch never carries this argument, so this
        // branch never runs in production. Without it, `PassengerUITests`
        // would only ever see a clean ledger on a simulator's very first
        // run — every rerun after that would find yesterday's answer still
        // on disk and fail the "toast appears" assertion for reasons that
        // have nothing to do with the code under test.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetLocalQA") {
            try? FileManager.default.removeItem(at: self.fileURL)
        }
    }

    func save(_ file: LocalQAFile, generation: Int) async {
        guard generation > lastWrittenGeneration else { return }
        lastWrittenGeneration = generation
        guard let data = try? JSONEncoder().encode(file) else { return }

        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard (try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) != nil
        else { return }

        var excludedURL = fileURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? excludedURL.setResourceValues(resourceValues)
    }

    func loadIfPresent() async -> LocalQAFile? {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(LocalQAFile.self, from: data)
        else { return nil }
        return file
    }
}
