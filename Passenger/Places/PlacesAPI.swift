import Foundation

/// Seam so `PlaceCatalog` can be tested against a fake without a network call
/// — same idiom as `DensityFetching` (TRD §3.4.1, "no new pattern").
protocol PlacesFetching: Sendable {
    func fetchPlaces() async throws -> [PlacesAPI.HoodPlacesRow]
}

/// `URLSession` + PostgREST, one embedded GET (TRD §4.3).
///
/// **Build Phase 1: this whole type ships built and unexercised.**
/// `BuildPhase.seedIsAuthoritative` is `true`, so `PlaceCatalog.load()` never
/// calls `fetchPlaces()` in Phase 1 — this file is compiled, type-checked,
/// and unit-testable against fakes, but never run against a server until the
/// constant flips at Phase 2 (TRD §3.4.1, §4.3, §7).
struct PlacesAPI: PlacesFetching {
    /// One place row, nested inside its Hood in the response (TRD §4.3). No
    /// `hood_id` on the wire here — under embedding a place's Hood is
    /// structural, so `PlaceCatalog` stamps `hoodID` from the enclosing
    /// `HoodPlacesRow.id` while walking the response, not from a per-row key.
    struct PlaceRow: Decodable, Sendable {
        let id: String
        let name: String
        let category: String
        let latitude: Double
        let longitude: Double
    }

    /// One Hood with its blurb and nested places — the shape one round trip
    /// returns (TRD §4.3).
    struct HoodPlacesRow: Decodable, Sendable {
        let id: String
        let blurb: String?
        let places: [PlaceRow]
    }

    enum PlacesAPIError: Error {
        case unconfigured
        case badResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Once per session, alongside `DensityStore.load()` (TRD §4.3). No query
    /// parameter carries anything user-specific — byte-identical for every
    /// user, same property T-031 §3.3 establishes.
    func fetchPlaces() async throws -> [HoodPlacesRow] {
        guard let config = AppConfig.supabase else {
            // A missing plist is a valid state, not a crash (§4.3) — the
            // caller (`PlaceCatalog.load()`) treats this like any other fetch
            // failure and falls back to cache/seed/unavailable.
            throw PlacesAPIError.unconfigured
        }

        guard var components = URLComponents(
            url: config.url.appendingPathComponent("rest/v1/hoods"),
            resolvingAgainstBaseURL: false
        ) else {
            throw PlacesAPIError.badResponse
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,blurb,places(id,name,category,latitude,longitude)"),
            URLQueryItem(name: "city", value: "eq.tel-aviv"),
        ]
        guard let url = components.url else { throw PlacesAPIError.badResponse }

        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PlacesAPIError.badResponse
        }
        return try JSONDecoder().decode([HoodPlacesRow].self, from: data)
    }
}
