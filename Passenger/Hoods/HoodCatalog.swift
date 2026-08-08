import CoreLocation
import Foundation
import MapKit

/// Bundled-resource loader (TRD §3.2, §4.2, §8 D3). Supabase's `hoods` table is
/// the authoring source; the client never fetches geometry at launch —
/// `Resources/hoods-tel-aviv.json` is a build-time export, committed.
enum HoodCatalog {
    struct CatalogFile: Decodable {
        struct Entry: Decodable {
            let id: String
            let name: String
            /// `[[lng, lat], ...]` — TRD §3.2's flattened export shape
            /// (data-engineer's B3 build note flags a possible
            /// full-GeoJSON-vs-flattened-ring mismatch to resolve on export;
            /// this loader takes the flattened shape TRD §3.2 shows). Closed
            /// (`first == last`) or open — hood-dataset TRD §4.2 requires the
            /// wire form be closed from schemaVersion 2 on, but this loader
            /// accepts both, since both are in the repo right now.
            let polygon: [[Double]]
            /// `[lng, lat]`, precomputed by the generator (hood-dataset TRD §8
            /// D5). Absent in a stale (schemaVersion 1) bundle — `load()` falls
            /// back to the averaged-vertex centroid when this is `nil`.
            let centroid: [Double]?
            /// `nil`/absent == not curated. `""`/whitespace-only is a
            /// build-time authoring defect the client also guards against
            /// (hood-dataset TRD §3.1, §4.3) — both layers normalising it is
            /// correct, not redundant.
            let blurb: String?
            /// `nil`/absent == not yet rated (three states).
            let isTouristTrap: Bool?
            /// Absent in a schemaVersion 1 bundle — defaults to `false`
            /// (hood-dataset TRD §4.3), matching `hoods.designated_for_progression`'s
            /// own `not null default false`.
            let designatedForProgression: Bool?
            /// Absent in a pre-schemaVersion-3 bundle — defaults to `[]`
            /// (hood-dataset TRD §3.1 D11), matching `hoods.aliases`'s own
            /// `not null default '{}'`.
            let aliases: [String]?
        }
        let schemaVersion: Int
        let generatedAt: String
        let city: String
        let hoods: [Entry]
    }

    enum CatalogError: Error, Equatable {
        case resourceMissing
        case malformed(String)
    }

    /// Throws rather than returning `[]` — a corrupt bundled resource is a build
    /// defect, not a runtime empty state (`passenger-code/CLAUDE.md`, fail fast).
    /// Intended to be called off the main actor by `MapScreen`; the map renders
    /// before this resolves (§5.1).
    static func load(resourceName: String = "hoods-tel-aviv", bundle: Bundle = .main) throws -> [Hood] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CatalogError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(CatalogFile.self, from: data)

        // §4.3: `schemaVersion` must be present and >= 1. An unknown *higher*
        // version is not rejected — a decoder facing a newer bundle than it
        // was written against already ignores keys it doesn't know about
        // correctly, and a hard version-equality gate would only turn that
        // working case into a crash.
        guard file.schemaVersion >= 1 else {
            throw CatalogError.malformed("unsupported schemaVersion \(file.schemaVersion)")
        }

        return try file.hoods.map { entry in
            guard entry.polygon.count >= 3 else {
                throw CatalogError.malformed("\(entry.id): fewer than 3 points")
            }
            var coordinates: [CLLocationCoordinate2D] = try entry.polygon.map { pair in
                guard pair.count == 2 else {
                    throw CatalogError.malformed("\(entry.id): malformed point \(pair)")
                }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }

            // §4.2: closed on the wire, open in memory. Drop a trailing
            // duplicate of the first point when present, exactly once — both
            // a closed ring (schemaVersion 2+, the generator's canonical form)
            // and an open one (today's shipped schemaVersion 1 bundles) must
            // load. `HoodCatalog.centroid(of:)` is an average of vertices, so
            // leaving the duplicate in would silently double-weight one corner.
            if coordinates.count > 1,
               let first = coordinates.first, let last = coordinates.last,
               first.latitude == last.latitude, first.longitude == last.longitude {
                coordinates.removeLast()
            }
            guard coordinates.count >= 3 else {
                throw CatalogError.malformed("\(entry.id): fewer than 3 distinct points")
            }

            let ring = coordinates.map(MKMapPoint.init)
            let boundingRect = ring.dropFirst().reduce(MKMapRect(origin: ring[0], size: MKMapSize(width: 0, height: 0))) { rect, point in
                rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
            }

            let resolvedCentroid: CLLocationCoordinate2D
            if let centroidPair = entry.centroid {
                guard centroidPair.count == 2 else {
                    throw CatalogError.malformed("\(entry.id): malformed centroid \(centroidPair)")
                }
                resolvedCentroid = CLLocationCoordinate2D(latitude: centroidPair[1], longitude: centroidPair[0])
            } else {
                resolvedCentroid = centroid(of: coordinates)
            }

            return Hood(
                id: entry.id,
                name: entry.name,
                ring: ring,
                boundingRect: boundingRect,
                centroid: resolvedCentroid,
                blurb: normalizedBlurb(entry.blurb),
                isTouristTrap: entry.isTouristTrap,
                designatedForProgression: entry.designatedForProgression ?? false,
                aliases: entry.aliases ?? []
            )
        }
    }

    /// `""` and whitespace-only are not curated copy (hood-dataset TRD §3.1,
    /// §4.3) — normalise both to `nil` rather than shipping placeholder text.
    private static func normalizedBlurb(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return raw
    }

    /// Average-of-vertices centroid — adequate for label placement on small,
    /// roughly-convex neighborhood shapes; not a true polygon-area centroid.
    private static func centroid(of coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        let count = Double(coordinates.count)
        let lat = coordinates.reduce(0) { $0 + $1.latitude } / count
        let lon = coordinates.reduce(0) { $0 + $1.longitude } / count
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
