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
        /// places-been-saved TRD §3.2, D1 — non-optional. A payload missing
        /// this column throws out of `JSONDecoder.decode`, which
        /// `PlaceCatalog.load()` treats like any other fetch failure and
        /// falls back to cache/seed, never a silent `false`.
        let permanentlyClosed: Bool
        /// passport TRD §3.2, D2 — non-optional, same reasoning as
        /// `permanentlyClosed`: a missing column is a loud decode failure
        /// with a designed fallback, never a silent placeholder.
        let placeType: String
        /// tourist-trap-flag TRD §3.1, §11 C6 — `Bool?`, absent/`null` on the
        /// wire decodes to `nil` for free (three states, not a boolean).
        /// `var ... = nil`, not `let` — a `let` property with an initial
        /// value is silently excluded from `Decodable` synthesis entirely
        /// (it would always decode to `nil` even when the JSON carries a
        /// real value); `var` keeps both the default for manual
        /// construction and correct decoding.
        var isTouristTrap: Bool? = nil
        /// search-quick-filters TRD §3.2 — non-optional. A payload missing
        /// this column throws out of `JSONDecoder.decode`, same fallback
        /// path as `permanentlyClosed`/`placeType` above.
        let keywords: [String]

        enum CodingKeys: String, CodingKey {
            case id, name, category, latitude, longitude, keywords
            case permanentlyClosed = "permanently_closed"
            case placeType = "place_type"
            case isTouristTrap = "is_tourist_trap"
        }
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
        // places-been-saved TRD §3.2/§11 C1 + tourist-trap-flag TRD §11 C6 +
        // passport TRD §3.2/§11 C1 + search-quick-filters TRD §3.2/§11 C1 —
        // widens the nested `places(...)` select to include
        // `permanently_closed`, `is_tourist_trap`, `place_type` and
        // `keywords`, completing T-042 §3 D5's four-column assignment.
        components.queryItems = [
            URLQueryItem(
                name: "select",
                value: "id,blurb,places(id,name,category,latitude,longitude,permanently_closed,place_type,is_tourist_trap,keywords)"
            ),
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
