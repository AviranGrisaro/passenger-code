import Foundation

/// Immutable, already-fetched hood/hour → band lookup table (TRD §4.4).
///
/// Keys on a floored epoch-hour `Int`, not `Date` — `Date` equality across a
/// JSON-decoded `timestamptz` (fractional seconds, differing ISO 8601
/// renderings) is a plausible source of silent lookup misses that a
/// `HeatBand?` "no data" default would mask rather than crash on
/// (`ios-developer`'s trd-review note on §4.4).
struct DensitySnapshot: Sendable {
    private let bands: [String: [Int: HeatBand]]  // [hoodID: [epochHour: HeatBand]]

    static let empty = DensitySnapshot(bands: [:])

    init(bands: [String: [Int: HeatBand]]) {
        self.bands = bands
    }

    /// Boundary validation (`passenger-code/CLAUDE.md`, fail fast at
    /// boundaries): each row is validated independently. An unknown `band`
    /// integer or an unparseable `hour_bucket` drops just that row — it never
    /// fails the whole snapshot and never crashes (TRD §4.5).
    init(rows: [DensityAPI.Row]) {
        let strict = ISO8601DateFormatter()
        strict.formatOptions = [.withInternetDateTime]
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var table: [String: [Int: HeatBand]] = [:]
        for row in rows {
            guard let band = HeatBand(rawValue: row.band) else { continue }
            guard let date = strict.date(from: row.hourBucket) ?? fractional.date(from: row.hourBucket) else { continue }
            let epochHour = Int(date.timeIntervalSince1970 / 3600)
            table[row.hoodID, default: [:]][epochHour] = band
        }
        self.bands = table
    }

    /// `nil` means no data — never a default band (PRD req 7).
    func band(for hoodID: String, epochHour: Int) -> HeatBand? {
        bands[hoodID]?[epochHour]
    }
}
