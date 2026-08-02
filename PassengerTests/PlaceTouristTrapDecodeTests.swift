import Foundation
import Testing
@testable import Passenger

/// tourist-trap-flag TRD §11 C6: `Place.isTouristTrap` decodes on all three
/// `PlaceCatalog` paths (seed/live/cache). A separate file from
/// `PlaceCatalogTests.swift` on purpose — that file is concurrently owned by
/// another in-flight task's build in this working tree, and reuses the same
/// bundled fixtures (`places-test-fixture.json`, `hoods-with-blurb-fixture.json`)
/// this suite also reads, rather than touching that file directly.
@Suite("Place.isTouristTrap decode")
@MainActor
struct PlaceTouristTrapDecodeTests {
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

    // MARK: - Seed path

    @Test("seed decode: true/false/absent all resolve correctly, per place")
    func seedDecodesAllThreeStates() async {
        let catalog = PlaceCatalog(
            seedResourceName: "places-test-fixture", hoodResourceName: "hoods-with-blurb-fixture",
            bundle: Self.testBundle
        )
        await catalog.load()

        // Fixture: florentin-cafe = true, florentin-museum = false,
        // orphan-place has no `is_tourist_trap` key at all.
        #expect(catalog.place(id: "florentin-cafe")?.isTouristTrap == true)
        #expect(catalog.place(id: "florentin-museum")?.isTouristTrap == false)
        #expect(catalog.place(id: "orphan-place")?.isTouristTrap == nil)
    }

    @Test("the real shipped seed bundle carries a mix of true/false/null, never a fourth state")
    func shippedBundleCarriesAllThreeStates() async {
        // Default `bundle: .main` — `PassengerTests` runs hosted, so this is
        // the real compiled app bundle's `places-tel-aviv.json`.
        let catalog = PlaceCatalog()
        await catalog.load()

        #expect(catalog.source == .seed)
        let values = catalog.allPlaces.map(\.isTouristTrap)
        #expect(values.contains(true))
        #expect(values.contains(false))
        #expect(values.contains(nil))
    }

    // MARK: - Live path (`PlacesAPI.PlaceRow`, built to spec, unexercised in Phase 1)

    @Test("a live payload's PlaceRow decodes is_tourist_trap: true")
    func liveDecodeTrue() throws {
        let json = """
        [{"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":false,"is_tourist_trap":true}]
        """.data(using: .utf8)!
        let rows = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        #expect(rows.first?.isTouristTrap == true)
    }

    @Test("a live payload's PlaceRow with a missing is_tourist_trap key decodes to nil, not a decode failure")
    func liveDecodeMissingKeyIsNil() throws {
        let json = """
        [{"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":false}]
        """.data(using: .utf8)!
        let rows = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        #expect(rows.first?.isTouristTrap == nil)
    }

    @Test("a live payload's PlaceRow with an explicit null decodes to nil")
    func liveDecodeExplicitNullIsNil() throws {
        let json = """
        [{"id":"a","name":"A","category":"eat-drink","latitude":32.05,"longitude":34.77,"permanently_closed":false,"is_tourist_trap":null}]
        """.data(using: .utf8)!
        let rows = try JSONDecoder().decode([PlacesAPI.PlaceRow].self, from: json)
        #expect(rows.first?.isTouristTrap == nil)
    }

    // MARK: - Cache path (`PlacesCache.CachedPlace`)

    @Test("a cached place round-trips isTouristTrap through encode/decode")
    func cacheRoundTripsIsTouristTrap() throws {
        let cached = PlacesCache.CachedPlace(
            id: "a", name: "A", category: "eat-drink", hoodID: "florentin",
            latitude: 32.05, longitude: 34.77, permanentlyClosed: false, isTouristTrap: true
        )
        let payload = PlacesCache.Payload(places: [cached], hoodBlurbs: [:])
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PlacesCache.Payload.self, from: data)
        #expect(decoded.places.first?.isTouristTrap == true)
    }

    @Test("a cached place missing isTouristTrap decodes to nil, never a decode failure — an older cache file predates this field")
    func cacheMissingFieldIsNil() throws {
        let json = """
        {"places":[{"id":"a","name":"A","category":"eat-drink","hoodID":"florentin","latitude":32.05,"longitude":34.77,"permanentlyClosed":false}],"hoodBlurbs":{}}
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(PlacesCache.Payload.self, from: json)
        #expect(payload.places.first?.isTouristTrap == nil)
    }
}
