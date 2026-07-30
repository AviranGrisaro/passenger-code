import Foundation

/// Reads Supabase connection info from `SupabaseConfig.plist`, a developer-local,
/// gitignored file (`passenger-code/CLAUDE.md`, Safety — no secrets in code).
///
/// A missing or malformed plist is a valid state, not a crash: `DensityAPI`
/// reports `.unavailable`, the map renders with no fill, and the app builds and
/// runs for a developer with no credentials (TRD §4.5).
enum AppConfig {
    struct SupabaseConfig: Sendable {
        let url: URL
        let anonKey: String
    }

    /// `nil` when the plist is missing, unreadable, or missing a required key.
    static let supabase: SupabaseConfig? = loadSupabaseConfig()

    private static func loadSupabaseConfig() -> SupabaseConfig? {
        guard
            let plistURL = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: plistURL),
            let raw = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
            let urlString = raw["SUPABASE_URL"], let url = URL(string: urlString),
            let anonKey = raw["SUPABASE_ANON_KEY"], !anonKey.isEmpty
        else {
            return nil
        }
        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}
