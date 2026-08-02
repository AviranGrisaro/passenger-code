import Foundation

/// Seam so `EventStore` can be tested against a fake without a network call —
/// same idiom as `DensityFetching`/`PlacesFetching` (TRD §4.1).
protocol EventsFetching: Sendable {
    func fetchEvents(anchorHour: Date) async throws -> [EventsAPI.Row]
}

/// `URLSession` + PostgREST GET against `events_public` (TRD §4.2).
///
/// **Build Phase 1: this whole type ships built and unexercised.**
/// `BuildPhase.eventSeedIsAuthoritative` is `true`, so `EventStore.load()`
/// never calls `fetchEvents()` in Phase 1 — this file is compiled,
/// type-checked, and unit-testable against fakes, but never run against a
/// server until the constant flips at Build Phase 3 (§7).
struct EventsAPI: EventsFetching {
    /// Matches `events_public`'s column list exactly (T-043 §4.2). Nullable
    /// columns are `Optional` here; per-row validation (a malformed
    /// timestamp, an out-of-range coordinate) happens in `LiveEvent.init(row:)`,
    /// not here — a single bad row must never fail the whole decode.
    struct Row: Decodable, Sendable {
        let id: String
        let name: String
        let startAt: String
        let endAt: String
        let lat: Double
        let lng: Double
        let venueName: String?
        let hoodID: String?
        let category: String?
        let rank: Double
        let sourceName: String?

        enum CodingKeys: String, CodingKey {
            case id, name, lat, lng, category, rank
            case startAt = "start_at"
            case endAt = "end_at"
            case venueName = "venue_name"
            case hoodID = "hood_id"
            case sourceName = "source_name"
        }
    }

    enum EventsAPIError: Error {
        case unconfigured
        case badResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// The request the URL itself carries (TRD §4.2, and the TRD's one
    /// contract edit against `live-events-pipeline/TRD.md` §4.2): **no
    /// `start_at=gte.{anchorHour}` lower bound.** That clause would silently
    /// delete every event already in progress at `anchorHour` — an event that
    /// started before "now" and is still running is exactly what this
    /// feature exists to show. Dropping it costs nothing: `events_public`
    /// already enforces `end_at > now()` as its own floor, so the set this
    /// query returns is "everything currently servable that starts before
    /// the window ends," bounded above by the 13h clause below and bounded
    /// below by the view itself, not by this client.
    ///
    /// Pure, so §9 row 3c's URL-shape check ("byte-identical for every
    /// device, carries nothing user-specific") needs no network call and no
    /// `AppConfig` singleton — the same seam discipline `EventSelection`/
    /// `EventHitTester` hold elsewhere in this module (TRD §2.2).
    static func buildURL(baseURL: URL, anchorHour: Date) -> URL? {
        let windowEnd = anchorHour.addingTimeInterval(13 * 3600)
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("rest/v1/events_public"),
            resolvingAgainstBaseURL: false
        ) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,name,start_at,end_at,lat,lng,venue_name,hood_id,category,rank,source_name"),
            URLQueryItem(name: "start_at", value: "lt.\(iso8601(windowEnd))"),
            URLQueryItem(name: "order", value: "rank.desc"),
        ]
        return components.url
    }

    /// Once per session, alongside `DensityStore.load()`/`PlaceCatalog.load()`
    /// (TRD §4.6). No query parameter carries anything user-specific —
    /// byte-identical for every device, the property T-031 §3.3 establishes
    /// and T-043 §4.2 preserves.
    func fetchEvents(anchorHour: Date) async throws -> [Row] {
        guard let config = AppConfig.supabase else {
            // A missing plist is a valid state, not a crash — the caller
            // (`EventStore.load()`) treats this exactly like any other fetch
            // failure and degrades to an honest empty layer, never to the
            // seed (§7, D8).
            throw EventsAPIError.unconfigured
        }
        guard let url = Self.buildURL(baseURL: config.url, anchorHour: anchorHour) else {
            throw EventsAPIError.badResponse
        }

        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EventsAPIError.badResponse
        }
        return try JSONDecoder().decode([Row].self, from: data)
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
