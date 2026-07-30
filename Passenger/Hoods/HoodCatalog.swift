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
            /// `[[lng, lat], ...]`, single ring, WGS84 — TRD §3.2's flattened
            /// export shape (data-engineer's B3 build note flags a possible
            /// full-GeoJSON-vs-flattened-ring mismatch to resolve on export;
            /// this loader takes the flattened shape TRD §3.2 shows).
            let polygon: [[Double]]
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

        return try file.hoods.map { entry in
            guard entry.polygon.count >= 3 else {
                throw CatalogError.malformed("\(entry.id): fewer than 3 points")
            }
            let coordinates: [CLLocationCoordinate2D] = try entry.polygon.map { pair in
                guard pair.count == 2 else {
                    throw CatalogError.malformed("\(entry.id): malformed point \(pair)")
                }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }
            let ring = coordinates.map(MKMapPoint.init)
            let boundingRect = ring.dropFirst().reduce(MKMapRect(origin: ring[0], size: MKMapSize(width: 0, height: 0))) { rect, point in
                rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
            }
            return Hood(
                id: entry.id,
                name: entry.name,
                ring: ring,
                boundingRect: boundingRect,
                centroid: centroid(of: coordinates)
            )
        }
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
