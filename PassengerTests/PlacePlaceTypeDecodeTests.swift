import Foundation
import Testing
@testable import Passenger

/// passport TRD §3.2, §11 C1: `Place.placeType` decodes on all three
/// `PlaceCatalog` paths (seed/live/cache), non-optional. A separate file
/// from `PlaceCatalogTests.swift` on purpose — same reason
/// `PlaceTouristTrapDecodeTests.swift` gives: that file is concurrently
/// owned by another in-flight task's build in this working tree, and this
/// suite reuses the same bundled fixtures (`places-test-fixture.json`,
/// `hoods-with-blurb-fixture.json`) rather than touching it directly.
@Suite("Place.placeType decode")
@MainActor
struct PlacePlaceTypeDecodeTests {
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

    // MARK: - Seed path

    @Test("seed decode: place_type is non-empty for every place, including the seed-only orphan-Hood row")
    func seedDecodesPlaceType() async {
        let catalog = PlaceCatalog(
            seedResourceName: "places-test-fixture", hoodResourceName: "hoods-with-blurb-fixture",
            bundle: Self.testBundle
        )
        await catalog.load()

        // Fixture (`PassengerTests/Fixtures/places-test-fixture.json`).
        #expect(catalog.place(id: "florentin-cafe")?.placeType == "cafe")
        #expect(catalog.place(id: "florentin-museum")?.placeType == "museum")
        #expect(catalog.place(id: "orphan-place")?.placeType == "bar")
    }

    @Test("a bundled seed missing place_type on any row fails to decode as a whole, not a per-row drop")
    func seedMissingPlaceTypeFailsWholeDecode() {
        let json = """
        {"schemaVersion":1,"places":[{"id":"a","name":"A","category":"eat-drink","hood_id":"florentin","latitude":32.05,"longitude":34.77,"permanently_closed":false}]}
        """.data(using: .utf8)!
        struct Probe: Decodable {
            struct Entry: Decodable {
                let placeType: String
                enum CodingKeys: String, CodingKey { case placeType = "place_type" }
            }
            let places: [Entry]
        }
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(Probe.self, from: json)
        }
    }

    @Test("the real shipped seed bundle decodes place_type on all nine places, exactly the six curated values")
    func shippedBundleCarriesSixPlaceTypeValues() async {
        // Default `bundle: .main` — `PassengerTests` runs hosted, so this is
        // the real compiled app bundle's `places-tel-aviv.json`.
        let catalog = PlaceCatalog()
        await catalog.load()

        #expect(catalog.source == .seed)
        #expect(catalog.allPlaces.count == 9)
        let values = Set(catalog.allPlaces.map(\.placeType))
        #expect(values == ["bar", "cafe", "landmark", "market", "museum", "restaurant"])
        // Non-optional, non-empty for every place — no place ships with a
        // blank placeholder string (TRD §3.2).
        #expect(catalog.allPlaces.allSatisfy { !$0.placeType.isEmpty })
    }

    // MARK: - Live path (`PlacesAPI.PlaceRow`, built to spec, unexercised in Phase 1)

    @Test("a live payload's PlaceRow decodes place_type")
    func liveDecodesPlaceType() throws {
        // `keywords` is also required (search-quick-filters TRD §3.2) —
        // present here so this test still isolates `place_type`, not a
        // second, unrelated decode failure.
        let json = """
        [{"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":false,"place_type":"restaurant","keywords":[]}]
        """.data(using: .utf8)!
        let rows = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        #expect(rows.first?.placeType == "restaurant")
    }

    @Test("a live payload's PlaceRow JSON missing place_type fails to decode — falls back to cache/seed, never a silent value")
    func liveDecodeThrowsWhenPlaceTypeMissing() {
        let json = """
        [{"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":false}]
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        }
    }

    // MARK: - Cache path (`PlacesCache.CachedPlace`)

    @Test("a cached place round-trips placeType through encode/decode")
    func cacheRoundTripsPlaceType() throws {
        let cached = PlacesCache.CachedPlace(
            id: "a", name: "A", category: "eat-drink", hoodID: "florentin",
            latitude: 32.05, longitude: 34.77, permanentlyClosed: false, placeType: "market", isTouristTrap: nil,
            keywords: []
        )
        let payload = PlacesCache.Payload(places: [cached], hoodBlurbs: [:])
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PlacesCache.Payload.self, from: data)
        #expect(decoded.places.first?.placeType == "market")
    }

    @Test("an older PlacesCache.CachedPlace payload missing placeType fails to decode — falls through to the seed")
    func cacheDecodeThrowsWhenPlaceTypeMissing() {
        let json = """
        {"places":[{"id":"a","name":"A","category":"eat-drink","hoodID":"florentin","latitude":32.05,"longitude":34.77,"permanentlyClosed":false}],"hoodBlurbs":{}}
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(PlacesCache.Payload.self, from: json)
        }
    }
}
