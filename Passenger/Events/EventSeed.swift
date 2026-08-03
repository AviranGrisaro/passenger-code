import CoreLocation
import Foundation

/// Build Phase 1 fixture loader (TRD §3.4, §8 D10). Resolves the bundled
/// `events-tel-aviv-seed.json`'s relative offsets against the *current*
/// `anchorHour`, so the fixture is never stale — an events file of absolute
/// timestamps would be empty by the next day, since every row would fail the
/// `endAt > now` filter (§3.4). Correct at any launch on any date, and flows
/// through the identical `LiveEvent` values the live path (`EventsAPI`) will
/// eventually produce.
enum EventSeed {
    struct SeedFile: Decodable {
        struct Entry: Decodable {
            let id: String
            let name: String
            let startOffsetMinutes: Int
            let durationMinutes: Int
            let latitude: Double
            let longitude: Double
            let venueName: String?
            let hoodID: String?
            let category: String?
            let rank: Double
            let sourceName: String?

            enum CodingKeys: String, CodingKey {
                case id, name, rank, category
                case latitude = "lat"
                case longitude = "lng"
                case startOffsetMinutes = "start_offset_minutes"
                case durationMinutes = "duration_minutes"
                case venueName = "venue_name"
                case hoodID = "hood_id"
                case sourceName = "source_name"
            }
        }
        let schemaVersion: Int
        let events: [Entry]
    }

    enum SeedError: Error, Equatable {
        case resourceMissing
        case malformed(String)
    }

    /// Throws only when the *resource itself* is missing or malformed —
    /// mirrors `PlaceCatalog`'s bundled-seed rule, where a missing file is a
    /// build defect the caller reports as `.unavailable`, never a crash. A
    /// row-level defect (bad coordinate, non-positive duration) drops just
    /// that row via `compactMap`, same as `PlaceCatalog.apply(hoodRows:)`'s
    /// per-row boundary validation.
    static func events(anchorHour: Date, resourceName: String = "events-tel-aviv-seed", bundle: Bundle = .main) throws -> [LiveEvent] {
        let file = try decode(resourceName: resourceName, bundle: bundle)
        return file.events.compactMap { entry -> LiveEvent? in
            guard Self.isValidCoordinate(latitude: entry.latitude, longitude: entry.longitude) else { return nil }
            guard entry.durationMinutes > 0 else { return nil }

            let startAt = anchorHour.addingTimeInterval(Double(entry.startOffsetMinutes) * 60)
            let endAt = startAt.addingTimeInterval(Double(entry.durationMinutes) * 60)

            return LiveEvent(
                id: entry.id,
                name: entry.name,
                startAt: startAt,
                endAt: endAt,
                coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
                venueName: Self.normalized(entry.venueName),
                hoodID: entry.hoodID,
                category: Self.normalized(entry.category),
                rank: entry.rank,
                sourceName: Self.normalized(entry.sourceName)
            )
        }
    }

    private static func decode(resourceName: String, bundle: Bundle) throws -> SeedFile {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw SeedError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(SeedFile.self, from: data)
        guard file.schemaVersion >= 1 else {
            throw SeedError.malformed("unsupported schemaVersion \(file.schemaVersion)")
        }
        return file
    }

    /// `""`/whitespace-only normalises to `nil` — same rule `PlaceCatalog`/`HoodCatalog` apply.
    private static func normalized(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return raw
    }

    private static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
