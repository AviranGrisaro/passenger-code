import CoreLocation
import Foundation

/// One session-scoped load, read by both sheets and the pin layer (TRD §3.3,
/// §4.4). `places(in:)`/`blurb(for:)`/`place(id:)` are dictionary reads
/// against already-fetched data — no code path fetches when a sheet opens or
/// a row is tapped, which is what makes the design spec's sub-400ms,
/// no-spinner open real.
///
/// **Build Phase 1 (TRD §3.4.1, §8 D10):** `BuildPhase.seedIsAuthoritative`
/// pins the bundled seed as the *authoritative* source — `load()` attempts no
/// fetch at all, deterministically, on every machine. The live → cache →
/// seed → empty precedence below it (§3.4) is built in full and unit-tested
/// against fakes, but not exercised against a server until Phase 2 flips the
/// constant.
@MainActor
@Observable
final class PlaceCatalog {
    enum Source: Sendable {
        case live
        case cache
        case seed
        case unavailable
    }

    enum CatalogError: Error, Equatable {
        case resourceMissing
        case malformed(String)
    }

    private(set) var source: Source = .unavailable
    /// PRD req 3 / TRD §4.5 — the pin layer and `PlaceHitTester` read this,
    /// never a per-Hood fetch.
    private(set) var allPlaces: [Place] = []

    private var placesByHood: [String: [Place]] = [:]
    private var placesByID: [String: Place] = [:]
    /// `nil` == not curated, never a placeholder empty string (TRD §3.1, §4.4).
    private var blurbsByHood: [String: String] = [:]

    private let api: any PlacesFetching
    private let cache: any PlacesCaching
    /// Test-only override points, mirroring `HoodCatalog.load(resourceName:bundle:)`'s
    /// own injection seam — not part of this task's contracted API surface,
    /// just the mechanism the contracted `init(api:cache:)` seam needs to be
    /// testable against a fixture bundle rather than the shipped app bundle.
    private let seedResourceName: String
    private let hoodResourceName: String
    private let bundle: Bundle

    /// The contracted seam (TRD §3.4.1): protocol + default argument, exactly
    /// `DensityStore.init(api:cache:now:)`. This is what makes assertions 2
    /// and 3 in `PlaceCatalogTests` real rather than narrative.
    init(
        api: any PlacesFetching = PlacesAPI(),
        cache: any PlacesCaching = PlacesCache(),
        seedResourceName: String = "places-tel-aviv",
        hoodResourceName: String = "hoods-tel-aviv",
        bundle: Bundle = .main
    ) {
        self.api = api
        self.cache = cache
        self.seedResourceName = seedResourceName
        self.hoodResourceName = hoodResourceName
        self.bundle = bundle
    }

    /// Name-ordered; `[]` is a real answer (TRD §4.4).
    func places(in hoodID: String) -> [Place] {
        placesByHood[hoodID] ?? []
    }

    func place(id: Place.ID) -> Place? {
        placesByID[id]
    }

    /// `nil` == not curated, never a placeholder (TRD §3.1, §4.4). In `.seed`
    /// mode this reads the *bundled Hood record's* blurb, not this catalog's
    /// own file — `places-tel-aviv.json` carries no blurb field at all
    /// (TRD §3.4.1 amendment); in `.live`/`.cache` mode it reads the blurb
    /// that arrived nested in the same response as the places.
    func blurb(for hoodID: String) -> String? {
        blurbsByHood[hoodID]
    }

    /// TRD §3.4: live fetch → last-good disk cache → bundled seed → empty.
    /// **In Build Phase 1 this precedence is not exercised** — the
    /// `BuildPhase.seedIsAuthoritative` branch below short-circuits straight
    /// to the bundled seed, deterministically, with no fetch attempted.
    func load() async {
        if BuildPhase.seedIsAuthoritative {
            loadFromBundledSeed()
            return
        }

        do {
            let payload = try await api.fetchPlaces()
            apply(hoodRows: payload, source: .live)
            await cache.save(places: cachedPlaces(from: payload), hoodBlurbs: blurbsByHood)
        } catch {
            if let cached = await cache.loadIfPresent() {
                apply(cachedPayload: cached)
            } else {
                loadFromBundledSeed()
            }
        }
    }

    // MARK: - Live/cache application (built to spec, unexercised in Phase 1 — TRD §4.3)

    private func apply(hoodRows: [PlacesAPI.HoodPlacesRow], source: Source) {
        var byHood: [String: [Place]] = [:]
        var byID: [String: Place] = [:]
        var blurbs: [String: String] = [:]
        var flat: [Place] = []

        for hoodRow in hoodRows {
            if let normalized = Self.normalizedBlurb(hoodRow.blurb) {
                blurbs[hoodRow.id] = normalized
            }
            for row in hoodRow.places {
                // Boundary validation, one row at a time (`passenger-code/CLAUDE.md`,
                // TRD §4.3) — a bad row is dropped, never crashes, never fails
                // the whole payload. `hoodID` is stamped from the enclosing
                // Hood, not read from a per-row key (TRD §4.3).
                guard let category = PlaceCategory(rawValue: row.category) else { continue }
                guard Self.isValidCoordinate(latitude: row.latitude, longitude: row.longitude) else { continue }
                let place = Place(
                    id: row.id,
                    name: row.name,
                    category: category,
                    hoodID: hoodRow.id,
                    coordinate: CLLocationCoordinate2D(latitude: row.latitude, longitude: row.longitude)
                )
                byHood[hoodRow.id, default: []].append(place)
                byID[place.id] = place
                flat.append(place)
            }
        }
        commit(byHood: byHood, byID: byID, blurbs: blurbs, flat: flat, source: source)
    }

    private func apply(cachedPayload: PlacesCache.Payload) {
        var byHood: [String: [Place]] = [:]
        var byID: [String: Place] = [:]
        var flat: [Place] = []
        for cached in cachedPayload.places {
            guard let category = PlaceCategory(rawValue: cached.category) else { continue }
            guard Self.isValidCoordinate(latitude: cached.latitude, longitude: cached.longitude) else { continue }
            let place = Place(
                id: cached.id,
                name: cached.name,
                category: category,
                hoodID: cached.hoodID,
                coordinate: CLLocationCoordinate2D(latitude: cached.latitude, longitude: cached.longitude)
            )
            byHood[cached.hoodID, default: []].append(place)
            byID[place.id] = place
            flat.append(place)
        }
        commit(byHood: byHood, byID: byID, blurbs: cachedPayload.hoodBlurbs, flat: flat, source: .cache)
    }

    private func cachedPlaces(from rows: [PlacesAPI.HoodPlacesRow]) -> [PlacesCache.CachedPlace] {
        rows.flatMap { hoodRow in
            hoodRow.places.compactMap { row -> PlacesCache.CachedPlace? in
                guard PlaceCategory(rawValue: row.category) != nil,
                      Self.isValidCoordinate(latitude: row.latitude, longitude: row.longitude)
                else { return nil }
                return PlacesCache.CachedPlace(
                    id: row.id, name: row.name, category: row.category,
                    hoodID: hoodRow.id, latitude: row.latitude, longitude: row.longitude
                )
            }
        }
    }

    // MARK: - Bundled seed (TRD §3.4, §3.4.1, §4.3)

    private struct SeedFile: Decodable {
        struct Entry: Decodable {
            let id: String
            let name: String
            let category: String
            let hoodID: String
            let latitude: Double
            let longitude: Double
            // `place_type`, `keywords`, `permanently_closed`, `is_tourist_trap`
            // deliberately undeclared: `Decodable` ignores unknown JSON keys,
            // and this task's `Place` model carries none of them (TRD §8 D7).

            enum CodingKeys: String, CodingKey {
                case id, name, category, latitude, longitude
                case hoodID = "hood_id"
            }
        }
        let schemaVersion: Int
        let places: [Entry]
    }

    /// The seed is a floor, never a cache: loading it never throws out of
    /// `load()` — a corrupt or missing bundled seed reports `.unavailable`
    /// with an empty catalog, same as a failed fetch with no cache
    /// (TRD §4.3's "never fails the whole payload, never crashes").
    private func loadFromBundledSeed() {
        guard let seed = try? Self.decodeSeed(resourceName: seedResourceName, bundle: bundle) else {
            commit(byHood: [:], byID: [:], blurbs: [:], flat: [], source: .unavailable)
            return
        }

        // Seed-only boundary rule (TRD §4.3): a `hood_id` absent from the
        // bundled Hood catalog still keeps the place — it renders as a pin
        // and appears in no Hood sheet. That falls out for free below:
        // nothing here filters a place by whether its `hoodID` resolves to a
        // known Hood, so an unmatched one simply has no `placesByHood` entry.
        var byHood: [String: [Place]] = [:]
        var byID: [String: Place] = [:]
        var flat: [Place] = []
        for entry in seed.places {
            guard let category = PlaceCategory(rawValue: entry.category) else { continue }
            guard Self.isValidCoordinate(latitude: entry.latitude, longitude: entry.longitude) else { continue }
            let place = Place(
                id: entry.id,
                name: entry.name,
                category: category,
                hoodID: entry.hoodID,
                coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)
            )
            byHood[entry.hoodID, default: []].append(place)
            byID[place.id] = place
            flat.append(place)
        }

        // §3.4.1 amendment: in `.seed` mode, `blurb(for:)` reads the bundled
        // *Hood* record, because this file carries no blurb field at all.
        // Read via `HoodCatalog.load()` directly rather than threading
        // `MapScreen`'s own `[Hood]` state through — the bundled resource is
        // tiny (dozens of Hoods) and this keeps `PlaceCatalog` independently
        // loadable/testable. A corrupt Hood bundle is `MapScreen`'s own
        // fatal-error case (TRD §4.2 of `map-hoods-heat`); here it degrades
        // to "no blurbs" rather than duplicating that crash, since
        // `PlaceCatalog.load()` itself must never crash (TRD §4.3).
        let blurbs = (try? HoodCatalog.load(resourceName: hoodResourceName, bundle: bundle))
            .map { hoods in
                Dictionary(uniqueKeysWithValues: hoods.compactMap { hood in hood.blurb.map { (hood.id, $0) } })
            } ?? [:]

        commit(byHood: byHood, byID: byID, blurbs: blurbs, flat: flat, source: .seed)
    }

    private static func decodeSeed(resourceName: String, bundle: Bundle) throws -> SeedFile {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CatalogError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(SeedFile.self, from: data)
        guard file.schemaVersion >= 1 else {
            throw CatalogError.malformed("unsupported schemaVersion \(file.schemaVersion)")
        }
        return file
    }

    // MARK: - Shared helpers

    private func commit(
        byHood: [String: [Place]], byID: [String: Place], blurbs: [String: String],
        flat: [Place], source: Source
    ) {
        placesByHood = byHood.mapValues { $0.sorted { $0.name < $1.name } }
        placesByID = byID
        blurbsByHood = blurbs
        allPlaces = flat
        self.source = source
    }

    /// `""`/whitespace-only is not curated copy (TRD §3.1, §4.3) — normalise
    /// both to `nil` rather than shipping placeholder text.
    private static func normalizedBlurb(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return raw
    }

    private static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
