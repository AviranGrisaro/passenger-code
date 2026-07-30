import Foundation

/// Seam so `DensityStore` can be tested against a fake without touching disk.
protocol DensityCaching: Sendable {
    func save(rows: [DensityAPI.Row]) async
    func loadIfPresent() async -> [DensityAPI.Row]?
}

/// Last-good snapshot on disk (TRD §3.4) — a payload in Application Support,
/// not a preference (never `UserDefaults`). Contains only Hood-level synthetic
/// bands, no personal data (location is never in this file — TRD §3.3).
///
/// Because rows key on absolute hour, a cache read at a later clock time stays
/// correct on its own: rows still inside `[now, now+12h]` render, rows that
/// fell out of the window are simply absent — already the silent no-data
/// state. No staleness heuristic is needed; `DensityStore` always re-anchors
/// to the current hour, so this cache never has to know how old it is.
actor DensityCache: DensityCaching {
    private struct Payload: Codable {
        let rows: [CachedRow]
    }
    private struct CachedRow: Codable {
        let hoodID: String
        let hourBucket: String
        let band: Int
    }

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = dir.appendingPathComponent("density-cache.json")
    }

    func save(rows: [DensityAPI.Row]) async {
        let payload = Payload(rows: rows.map { CachedRow(hoodID: $0.hoodID, hourBucket: $0.hourBucket, band: $0.band) })
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    func loadIfPresent() async -> [DensityAPI.Row]? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return payload.rows.map { DensityAPI.Row(hoodID: $0.hoodID, hourBucket: $0.hourBucket, band: $0.band) }
    }
}
