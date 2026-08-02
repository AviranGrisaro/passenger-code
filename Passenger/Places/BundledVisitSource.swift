import Foundation

/// Build Phase 1's `VisitSourcing` conformer (TRD §3.3, §4.2): a bundled,
/// read-only fixture, not a detector's output — there is no dwell/geofence
/// detector in this codebase, and building one here would both violate the
/// PRD's "one detector, three consumers" rule and Build Phase 1's
/// fake/hardcoded-data scope. Test-only override points mirror
/// `PlaceCatalog`'s `seedResourceName`/`bundle` seam.
struct BundledVisitSource: VisitSourcing {
    private let resourceName: String
    private let bundle: Bundle

    init(resourceName: String = "place-visits-tel-aviv", bundle: Bundle = .main) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    /// A missing or malformed resource is `[:]`, never a crash — same
    /// posture as `PlaceCatalog.loadFromBundledSeed()`. A duplicate
    /// `place_id` in the fixture is a boundary error handled by
    /// `keepHigherKind`: keep the higher `VisitKind` and drop the other, so
    /// the file can never produce two rows for one place (TRD §3.4's
    /// update invariant, enforced here as the fixture-authoring rule).
    func loadVisits() async -> [Place.ID: VisitKind] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(VisitFile.self, from: data)
        else { return [:] }

        return Dictionary(
            file.visits.map { ($0.placeID, $0.kind) },
            uniquingKeysWith: Self.keepHigherKind
        )
    }

    private static func keepHigherKind(_ first: VisitKind, _ second: VisitKind) -> VisitKind {
        first.provenance > second.provenance ? first : second
    }

    private struct VisitFile: Decodable {
        struct Entry: Decodable {
            let placeID: String
            let kind: VisitKind
            enum CodingKeys: String, CodingKey {
                case placeID = "place_id"
                case kind
            }
        }
        let schemaVersion: Int
        let visits: [Entry]
    }
}
