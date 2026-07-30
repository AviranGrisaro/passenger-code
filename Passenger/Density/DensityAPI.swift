import Foundation

/// Seam so `DensityStore` can be tested against a fake without a network call.
protocol DensityFetching: Sendable {
    func fetchDensity(from anchorHour: Date) async throws -> [DensityAPI.Row]
}

/// `URLSession` + PostgREST, no SDK (TRD §2.3, §4.5). One unauthenticated GET
/// against a public-read table needs no `supabase-swift` dependency.
struct DensityAPI: DensityFetching {
    /// Matches `GET .../hood_density?select=hood_id,hour_bucket,band` exactly.
    /// Deliberately permissive at the JSON layer (`band` as `Int`, `hourBucket`
    /// as `String`) — the actual per-row validation (unknown band, unparseable
    /// timestamp) happens in `DensitySnapshot.init(rows:)`, one row at a time,
    /// not here. A single malformed row must never fail the whole decode.
    struct Row: Decodable, Sendable {
        let hoodID: String
        let hourBucket: String
        let band: Int

        enum CodingKeys: String, CodingKey {
            case hoodID = "hood_id"
            case hourBucket = "hour_bucket"
            case band
        }
    }

    enum DensityAPIError: Error {
        case unconfigured
        case badResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches `[anchorHour, anchorHour + 12h]`, once per session (§4.5). No
    /// query parameter carries anything user-specific — the request is
    /// byte-identical for every user of the app (TRD §3.3).
    func fetchDensity(from anchorHour: Date) async throws -> [Row] {
        guard let config = AppConfig.supabase else {
            // A missing plist is a valid state, not a crash (§4.5) — the caller
            // (`DensityStore.load()`) treats this exactly like any other fetch
            // failure and falls back to cache/unavailable.
            throw DensityAPIError.unconfigured
        }

        let endHour = anchorHour.addingTimeInterval(12 * 3600)
        guard var components = URLComponents(
            url: config.url.appendingPathComponent("rest/v1/hood_density"),
            resolvingAgainstBaseURL: false
        ) else {
            throw DensityAPIError.badResponse
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "hood_id,hour_bucket,band"),
            URLQueryItem(name: "hour_bucket", value: "gte.\(Self.iso8601(anchorHour))"),
            URLQueryItem(name: "hour_bucket", value: "lte.\(Self.iso8601(endHour))"),
        ]
        guard let url = components.url else { throw DensityAPIError.badResponse }

        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DensityAPIError.badResponse
        }
        return try JSONDecoder().decode([Row].self, from: data)
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
