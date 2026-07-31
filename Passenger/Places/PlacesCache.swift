import Foundation

/// Seam so `PlaceCatalog` can be tested against a fake without touching disk
/// — mirrors `DensityCaching` (TRD §2.1).
protocol PlacesCaching: Sendable {
    func save(places: [PlacesCache.CachedPlace], hoodBlurbs: [String: String]) async
    func loadIfPresent() async -> PlacesCache.Payload?
}

/// Last-good live payload on disk (TRD §3.4), same shape as `DensityCache` —
/// a payload in Application Support, not a preference. Contains only place
/// identity/geometry and Hood blurbs, no personal data.
///
/// **Build Phase 1: unexercised.** `PlaceCatalog.load()` never reaches the
/// live-fetch branch that would populate this cache (§3.4.1), so this actor
/// is built and unit-testable but never actually written to or read from in
/// Phase 1.
actor PlacesCache: PlacesCaching {
    struct CachedPlace: Codable, Sendable {
        let id: String
        let name: String
        let category: String
        let hoodID: String
        let latitude: Double
        let longitude: Double
    }

    struct Payload: Codable, Sendable {
        let places: [CachedPlace]
        /// Non-nil blurbs only, keyed by Hood id — the live path's source for
        /// `PlaceCatalog.blurb(for:)` (TRD §3.4.1 amendment).
        let hoodBlurbs: [String: String]
    }

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = dir.appendingPathComponent("places-cache.json")
    }

    func save(places: [CachedPlace], hoodBlurbs: [String: String]) async {
        let payload = Payload(places: places, hoodBlurbs: hoodBlurbs)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    func loadIfPresent() async -> Payload? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return payload
    }
}
