import Foundation

/// `place_type` → `StickerShape` — bundled, synchronous, **never fetched,
/// permanently in V1** (passport TRD §3.4, D4). A shape key the binary
/// cannot draw is useless however it arrives, so this does not call T-042's
/// `GET /rest/v1/place_types` — bundling keeps the shape vocabulary and its
/// assets in the same artifact, always in sync.
///
/// `.shared` is decoded once, on first access via a `static let` — **not**
/// wired into `PlaceCatalog.load()` or any `.task`. Two reasons: it is
/// bundled in every build phase, so hanging it off `PlaceCatalog`'s seed
/// branch would leave it unloaded the moment `BuildPhase.seedIsAuthoritative`
/// flips to `false`; and an async load would add a launch-path dependency to
/// a screen (Passport) that is not on the launch path.
///
/// A value type, not an enum namespace, so `PassportComposition.stickers`
/// can take it as a plain parameter (TRD §4.1) — a pure function over
/// already-loaded data, not a global lookup — and so tests can construct one
/// against a fixture bundle without touching `Bundle.main`.
struct PlaceTypeRegistry: Sendable {
    private let shapesByPlaceType: [String: StickerShape]

    /// The real shipped registry (`Resources/place-types-tel-aviv.json`,
    /// A1's content).
    static let shared = PlaceTypeRegistry()

    /// Test-only override point, mirroring `PlaceCatalog`'s
    /// `seedResourceName`/`bundle` seam.
    init(resourceName: String = "place-types-tel-aviv", bundle: Bundle = .main) {
        shapesByPlaceType = Self.decode(resourceName: resourceName, bundle: bundle)
    }

    /// `.generic` for an unregistered key — defence in depth (TRD §3.3),
    /// never a crash. C2's totality test and C12's bundle-coverage test make
    /// this branch unreachable in a shipped pair; it exists for the day a
    /// data/app skew makes it reachable anyway.
    func shape(for placeType: String) -> StickerShape {
        shapesByPlaceType[placeType] ?? .generic
    }

    /// Every key this registry actually carries — C2's totality test walks
    /// this, not a hardcoded list, so a future A1 edit is covered
    /// automatically.
    var registeredPlaceTypes: [String] {
        Array(shapesByPlaceType.keys)
    }

    private struct RegistryFile: Decodable {
        let schemaVersion: Int
        let types: [String: String]
    }

    /// A missing or corrupt file yields an empty map, never a crash — same
    /// posture as `PlaceCatalog.loadFromBundledSeed()`. An unrecognised
    /// shape word in the file (a typo, a shape not yet in `StickerShape`) is
    /// dropped by `compactMapValues`, not force-decoded — that key then
    /// resolves through `shape(for:)`'s `.generic` fallback like any other
    /// unregistered `place_type`.
    private static func decode(resourceName: String, bundle: Bundle) -> [String: StickerShape] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(RegistryFile.self, from: data)
        else { return [:] }
        return file.types.compactMapValues { StickerShape(rawValue: $0) }
    }
}
