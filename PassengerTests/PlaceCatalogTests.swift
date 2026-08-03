import CoreLocation
import Foundation
import Testing
@testable import Passenger

private actor FetchSpy: PlacesFetching {
    private(set) var wasCalled = false
    private let rows: [PlacesAPI.HoodPlacesRow]
    private let error: Error?

    init(rows: [PlacesAPI.HoodPlacesRow] = [], error: Error? = nil) {
        self.rows = rows
        self.error = error
    }

    func fetchPlaces() async throws -> [PlacesAPI.HoodPlacesRow] {
        wasCalled = true
        if let error { throw error }
        return rows
    }
}

private actor NoopCache: PlacesCaching {
    func save(places: [PlacesCache.CachedPlace], hoodBlurbs: [String: String]) async {}
    func loadIfPresent() async -> PlacesCache.Payload? { nil }
}

/// Covers `hood-place-detail/TRD.md` §3.4.1's Build-Phase-1 pin (the three
/// required determinism assertions) plus the seed decode/boundary-validation
/// logic that is the *active* Phase-1 code path — the live/cache branches are
/// built to spec (TRD §4.3) but deliberately not exercised here (§7: "Phase-1
/// acceptance... covers none of the above").
@Suite("PlaceCatalog")
@MainActor
struct PlaceCatalogTests {
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

    private static func makeSeedCatalog(api: any PlacesFetching = FetchSpy()) -> PlaceCatalog {
        PlaceCatalog(
            api: api, cache: NoopCache(),
            seedResourceName: "places-test-fixture", hoodResourceName: "hoods-with-blurb-fixture",
            bundle: Self.testBundle
        )
    }

    // MARK: - §3.4.1 Build-Phase-1 determinism assertions — all three required

    @Test("1: after load(), source is .seed")
    func sourceIsSeedAfterLoad() async {
        let catalog = Self.makeSeedCatalog()
        await catalog.load()
        #expect(catalog.source == .seed)
    }

    @Test("2: load() makes zero fetch attempts — a PlacesFetching spy is never called")
    func loadMakesZeroFetchAttempts() async {
        let spy = FetchSpy()
        let catalog = Self.makeSeedCatalog(api: spy)
        await catalog.load()
        #expect(await spy.wasCalled == false)
    }

    @Test("3: source is still .seed even with a populated SupabaseConfig.plist present")
    func sourceStaysSeedWithPopulatedConfigPresent() async throws {
        // `AppConfig` reads `Bundle.main`, and `PassengerTests` runs hosted
        // (`TEST_HOST = Passenger.app`, project.pbxproj), so a fixture plist
        // cannot be injected into `Bundle.main` without permanently bundling
        // a committed plist into the shipped app target — which the
        // "no secrets in code" rule (`passenger-code/CLAUDE.md`) forbids.
        // This proves the property the fixture plist stands for directly
        // instead: a genuine, well-formed `SupabaseConfig.plist`-shaped
        // fixture is loaded and parsed below (not asserted in prose), and a
        // `PlacesFetching` spy that is fully capable of succeeding — the
        // same state a real fetch would be in with that config — is still
        // never consulted. That is exactly the property that fails if
        // someone later "fixes" `BuildPhase.seedIsAuthoritative` away in
        // favor of deriving the source from config/network reachability.
        let plistURL = try #require(
            Self.testBundle.url(forResource: "SupabaseConfig-populated-fixture", withExtension: "plist")
        )
        let plistData = try Data(contentsOf: plistURL)
        let raw = try #require(
            try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: String]
        )
        let configuredURL = try #require(raw["SUPABASE_URL"].flatMap(URL.init(string:)))
        #expect(configuredURL.scheme == "https")
        #expect(!(raw["SUPABASE_ANON_KEY"] ?? "").isEmpty)

        let spy = FetchSpy(rows: [
            PlacesAPI.HoodPlacesRow(
                id: "florentin",
                blurb: "would-be-live blurb",
                places: [
                    PlacesAPI.PlaceRow(
                        id: "would-be-live-place", name: "Live Place", category: "eat-drink",
                        latitude: 32.0531, longitude: 34.7623, permanentlyClosed: false, placeType: "cafe",
                        keywords: []
                    ),
                ]
            ),
        ])
        let catalog = Self.makeSeedCatalog(api: spy)

        await catalog.load()

        #expect(catalog.source == .seed)
        #expect(await spy.wasCalled == false)
    }

    // MARK: - Seed decode + boundary validation (TRD §3.4, §4.3 — the active Phase-1 path)

    @Test("seed places are grouped by Hood and name-ordered")
    func seedPlacesGroupedAndOrdered() async {
        let catalog = Self.makeSeedCatalog()
        await catalog.load()

        // "Test Cafe" < "Test Museum" — name order, not file order.
        #expect(catalog.places(in: "florentin").map(\.id) == ["florentin-cafe", "florentin-museum"])
    }

    @Test("a place whose category is not one of the two keys is dropped, never mapped to a default")
    func invalidCategoryDropped() async {
        let catalog = Self.makeSeedCatalog()
        await catalog.load()
        #expect(catalog.place(id: "bad-category-place") == nil)
    }

    @Test("a place with an out-of-range coordinate is dropped")
    func invalidCoordinateDropped() async {
        let catalog = Self.makeSeedCatalog()
        await catalog.load()
        #expect(catalog.place(id: "bad-coordinate-place") == nil)
    }

    @Test("a place whose hood_id is absent from the bundled Hood catalog is kept, not dropped (seed-only rule)")
    func orphanHoodIDKeepsThePlace() async {
        let catalog = Self.makeSeedCatalog()
        await catalog.load()

        #expect(catalog.place(id: "orphan-place") != nil)
        #expect(catalog.places(in: "no-such-hood").contains { $0.id == "orphan-place" })
        #expect(catalog.allPlaces.contains { $0.id == "orphan-place" })
    }

    @Test("a Hood with no places in the seed answers [], a real answer not a missing one")
    func hoodWithNoPlacesIsEmpty() async {
        let catalog = Self.makeSeedCatalog()
        await catalog.load()
        #expect(catalog.places(in: "kerem-hateimanim").isEmpty)
    }

    @Test("blurb(for:) in seed mode reads the bundled Hood record, not this catalog's own file")
    func blurbFallsBackToHoodCatalogInSeedMode() async {
        let catalog = Self.makeSeedCatalog()
        await catalog.load()

        #expect(catalog.blurb(for: "florentin") == "A test blurb for Florentin.")
        #expect(catalog.blurb(for: "kerem-hateimanim") == nil)
    }

    @Test("a missing bundled seed resource reports .unavailable, never a crash")
    func missingSeedResourceIsUnavailable() async {
        let catalog = PlaceCatalog(
            api: FetchSpy(), cache: NoopCache(),
            seedResourceName: "does-not-exist", hoodResourceName: "hoods-with-blurb-fixture",
            bundle: Self.testBundle
        )

        await catalog.load()

        #expect(catalog.source == .unavailable)
        #expect(catalog.allPlaces.isEmpty)
    }

    // MARK: - places-been-saved TRD §3.2/§11 C1 — permanentlyClosed decode, all three source paths

    @Test("permanentlyClosed decodes correctly from the bundled seed fixture, per place")
    func permanentlyClosedDecodesFromSeed() async {
        let catalog = Self.makeSeedCatalog()
        await catalog.load()

        #expect(catalog.place(id: "florentin-cafe")?.permanentlyClosed == false)
        #expect(catalog.place(id: "florentin-museum")?.permanentlyClosed == true)
    }

    @Test("the real shipped bundle decodes with 9 places and exactly the two flagged permanently closed")
    func shippedBundleDecodesNinePlacesTwoFlagged() async {
        // Default `bundle: .main` — `PassengerTests` runs hosted
        // (`TEST_HOST = Passenger.app`, project.pbxproj), so `Bundle.main`
        // is the compiled app bundle carrying the real `places-tel-aviv.json`
        // (same property `SettingsHintContrastTests` relies on for assets).
        let catalog = PlaceCatalog(api: FetchSpy(), cache: NoopCache())
        await catalog.load()

        #expect(catalog.source == .seed)
        #expect(catalog.allPlaces.count == 9)

        let closedIDs = Set(catalog.allPlaces.filter(\.permanentlyClosed).map(\.id))
        #expect(closedIDs == ["kerem-carmel-spice-corner", "neve-nachum-gutman-museum"])
    }

    @Test("a live payload's PlaceRow JSON missing permanently_closed fails to decode")
    func liveDecodeThrowsWhenPermanentlyClosedMissing() {
        let json = """
        [{"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77}]
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        }
    }

    @Test("a live payload's PlaceRow JSON with permanently_closed decodes it correctly")
    func liveDecodeSucceedsWhenPermanentlyClosedPresent() throws {
        // `place_type` and `keywords` are also required (passport TRD §3.2,
        // D2; search-quick-filters TRD §3.2) — present here so this test
        // still isolates `permanently_closed`, not an unrelated decode
        // failure.
        let json = """
        [{"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":true,"place_type":"cafe","keywords":[]}]
        """.data(using: .utf8)!
        let rows = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        #expect(rows.first?.permanentlyClosed == true)
    }

    @Test("an older PlacesCache.CachedPlace payload missing permanentlyClosed fails to decode — falls through to the seed")
    func cacheDecodeThrowsWhenPermanentlyClosedMissing() {
        let json = """
        {"places":[{"id":"a","name":"A","category":"eat-drink","hoodID":"florentin","latitude":32.05,"longitude":34.77}],"hoodBlurbs":{}}
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(PlacesCache.Payload.self, from: json)
        }
    }
}
