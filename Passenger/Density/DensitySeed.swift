import Foundation

/// Build Phase 1 density data (TRD §3.4, §8 D10). Follows `PlaceCatalog`'s
/// bundled-seed shape exactly — same injectable resource name/bundle, same
/// "never throws out of the caller" posture — but the file itself stores
/// **relative** offsets, not the wire shape: `DensityAPI.Row.hourBucket` is
/// an absolute ISO timestamp, and a bundled file of absolute timestamps
/// would be stale the moment it was authored. `rows(anchorHour:)`
/// synthesizes wire-shaped rows against the live `anchorHour` at load time,
/// so the seed is correct at any launch on any date and flows through the
/// same `DensitySnapshot` epoch-hour keying the live path uses.
///
/// `bands[offset]` is hour offset `0...12`; `null` means no row for that
/// hour — that absence is how req 2's silent-empty bullet gets exercised on
/// purpose rather than by accident (§3.4).
///
/// Authoring rule enforced by `DensitySeedTests` (§3.4, §10): at least 3
/// Hoods must change band across at least 4 adjacent hour pairs, and at
/// least one Hood must have a `null` entry — otherwise the differs-across-
/// hours check (§9 row 2a) and the perceptual repaint check both pass
/// vacuously.
enum DensitySeed {
    struct SeedFile: Decodable {
        struct HoodBands: Decodable {
            let hoodID: String
            /// 13 entries, index = hour offset 0...12. `HeatBand`'s raw
            /// values are 1...3 — this is `Int?`, not `HeatBand?`, so an
            /// out-of-range integer in the file is dropped per-entry at
            /// decode time (below) rather than failing the whole file, the
            /// same boundary-validation posture `DensitySnapshot.init(rows:)`
            /// already takes for a live row.
            let bands: [Int?]

            enum CodingKeys: String, CodingKey {
                case hoodID = "hood_id"
                case bands
            }
        }
        let schemaVersion: Int
        let hoods: [HoodBands]
    }

    /// The seed is a floor, never a cache: a missing or corrupt bundled file
    /// returns `.empty` rather than throwing — same posture
    /// `PlaceCatalog.loadFromBundledSeed()` takes (TRD §3.4).
    static func rows(
        anchorHour: Date,
        resourceName: String = "density-seed-tel-aviv",
        bundle: Bundle = .main
    ) -> [DensityAPI.Row] {
        guard let file = try? decode(resourceName: resourceName, bundle: bundle) else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var rows: [DensityAPI.Row] = []
        for hoodEntry in file.hoods {
            for (offset, rawBand) in hoodEntry.bands.enumerated() {
                guard offset <= 12, let rawBand, HeatBand(rawValue: rawBand) != nil else { continue }
                let hourBucket = anchorHour.addingTimeInterval(Double(offset) * 3600)
                rows.append(DensityAPI.Row(hoodID: hoodEntry.hoodID, hourBucket: formatter.string(from: hourBucket), band: rawBand))
            }
        }
        return rows
    }

    private static func decode(resourceName: String, bundle: Bundle) throws -> SeedFile {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SeedFile.self, from: data)
    }
}
