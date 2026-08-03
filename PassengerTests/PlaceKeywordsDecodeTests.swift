import Foundation
import Testing
@testable import Passenger

/// search-quick-filters TRD §3.2, §11 C1: `Place.keywords` decodes on all
/// three `PlaceCatalog` paths (seed/live/cache), non-optional, with an empty
/// array accepted as a real value. A separate file from `PlaceCatalogTests`/
/// `PlaceTouristTrapDecodeTests`/`PlacePlaceTypeDecodeTests` on purpose —
/// same reason those give: this working tree has several tasks' builds
/// in flight concurrently, and this suite reuses the same bundled fixtures
/// (`places-test-fixture.json`, `hoods-with-blurb-fixture.json`) rather than
/// touching those files directly.
@Suite("Place.keywords decode")
@MainActor
struct PlaceKeywordsDecodeTests {
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

    // MARK: - Seed path

    @Test("seed decode: keywords decode per place, including a genuinely empty array")
    func seedDecodesKeywords() async {
        let catalog = PlaceCatalog(
            seedResourceName: "places-test-fixture", hoodResourceName: "hoods-with-blurb-fixture",
            bundle: Self.testBundle
        )
        await catalog.load()

        // Fixture (`PassengerTests/Fixtures/places-test-fixture.json`).
        #expect(catalog.place(id: "florentin-cafe")?.keywords == ["coffee", "pastries"])
        #expect(catalog.place(id: "florentin-museum")?.keywords == ["art", "exhibits"])
        // An empty array keeps the place — it matches nothing, which is a
        // real value, not a decode failure (TRD §3.2).
        #expect(catalog.place(id: "orphan-place")?.keywords == [])
    }

    @Test("a bundled seed missing keywords on any row fails to decode as a whole, not a per-row drop to []")
    func seedMissingKeywordsFailsWholeDecode() {
        let json = """
        {"schemaVersion":1,"places":[{"id":"a","name":"A","category":"eat-drink","hood_id":"florentin","latitude":32.05,"longitude":34.77,"permanently_closed":false,"place_type":"cafe"}]}
        """.data(using: .utf8)!
        struct Probe: Decodable {
            struct Entry: Decodable {
                let keywords: [String]
            }
            let places: [Entry]
        }
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(Probe.self, from: json)
        }
    }

    @Test("the real shipped seed bundle decodes keywords on all nine places, none empty")
    func shippedBundleCarriesKeywordsOnEveryPlace() async {
        // Default `bundle: .main` — `PassengerTests` runs hosted, so this is
        // the real compiled app bundle's `places-tel-aviv.json`, which
        // carries a non-empty `keywords` array on every one of its 9 rows
        // (verified by reading the file directly — TRD §3.2).
        let catalog = PlaceCatalog()
        await catalog.load()

        #expect(catalog.source == .seed)
        #expect(catalog.allPlaces.count == 9)
        #expect(catalog.allPlaces.allSatisfy { !$0.keywords.isEmpty })
    }

    // MARK: - Live path (`PlacesAPI.PlaceRow`, built to spec, unexercised in Phase 1)

    @Test("a live payload's PlaceRow decodes keywords, including an empty array")
    func liveDecodesKeywords() throws {
        let json = """
        [
            {"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":false,"place_type":"cafe","keywords":["coffee","brunch"]},
            {"id":"b","name":"B","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":false,"place_type":"bar","keywords":[]}
        ]
        """.data(using: .utf8)!
        let rows = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        #expect(rows[0].keywords == ["coffee", "brunch"])
        #expect(rows[1].keywords == [])
    }

    @Test("a live payload's PlaceRow JSON missing keywords fails to decode — falls back to cache/seed, never a silent []")
    func liveDecodeThrowsWhenKeywordsMissing() {
        let json = """
        [{"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":false,"place_type":"cafe"}]
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        }
    }

    // MARK: - Cache path (`PlacesCache.CachedPlace`)

    @Test("a cached place round-trips keywords through encode/decode")
    func cacheRoundTripsKeywords() throws {
        let cached = PlacesCache.CachedPlace(
            id: "a", name: "A", category: "eat-drink", hoodID: "florentin",
            latitude: 32.05, longitude: 34.77, permanentlyClosed: false, placeType: "cafe", isTouristTrap: nil,
            keywords: ["coffee", "quiet"]
        )
        let payload = PlacesCache.Payload(places: [cached], hoodBlurbs: [:])
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PlacesCache.Payload.self, from: data)
        #expect(decoded.places.first?.keywords == ["coffee", "quiet"])
    }

    @Test("an older PlacesCache.CachedPlace payload missing keywords fails to decode — falls through to the seed (§7)")
    func cacheDecodeThrowsWhenKeywordsMissing() {
        let json = """
        {"places":[{"id":"a","name":"A","category":"eat-drink","hoodID":"florentin","latitude":32.05,"longitude":34.77,"permanentlyClosed":false,"placeType":"cafe"}],"hoodBlurbs":{}}
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(PlacesCache.Payload.self, from: json)
        }
    }
}
