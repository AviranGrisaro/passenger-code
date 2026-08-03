import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers search-quick-filters TRD §4.2's folding rule and index construction.
@Suite("SearchIndex")
struct SearchIndexTests {
    private static func place(id: String, name: String, hoodID: String, keywords: [String] = []) -> Place {
        Place(
            id: id, name: name, category: .eatDrink, hoodID: hoodID,
            coordinate: CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77),
            permanentlyClosed: false, placeType: "cafe", isTouristTrap: nil, keywords: keywords
        )
    }

    private static func hood(id: String, name: String) -> Hood {
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10)]
        return Hood(
            id: id, name: name, ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false
        )
    }

    @Test("fold is case- and diacritic-insensitive, and locale-independent")
    func foldNormalizes() {
        #expect(SearchIndex.fold("Café") == SearchIndex.fold("cafe"))
        #expect(SearchIndex.fold("FLORENTIN") == SearchIndex.fold("florentin"))
    }

    @Test("build produces one folded entry per place and per Hood, with the place's own Hood name attached")
    func buildProducesParallelEntries() {
        let florentin = Self.hood(id: "florentin", name: "Florentin")
        let cafe = Self.place(id: "a", name: "Café Noir", hoodID: "florentin", keywords: ["Espresso", "Quiet"])

        let index = SearchIndex.build(places: [cafe], hoods: [florentin])

        #expect(index.hoods.count == 1)
        #expect(index.hoods[0].foldedName == SearchIndex.fold("Florentin"))
        #expect(index.places.count == 1)
        let entry = index.places[0]
        #expect(entry.foldedName == SearchIndex.fold("Café Noir"))
        #expect(entry.foldedKeywords == ["Espresso", "Quiet"].map(SearchIndex.fold))
        #expect(entry.hoodName == "Florentin")
    }

    @Test("a place whose hood_id resolves to no known Hood gets an empty hoodName, not a crash")
    func orphanHoodIDYieldsEmptyHoodName() {
        let orphan = Self.place(id: "a", name: "Orphan", hoodID: "no-such-hood")
        let index = SearchIndex.build(places: [orphan], hoods: [])
        #expect(index.places[0].hoodName == "")
    }

    @Test(".empty has no places and no Hoods")
    func emptyIndexIsEmpty() {
        #expect(SearchIndex.empty.places.isEmpty)
        #expect(SearchIndex.empty.hoods.isEmpty)
    }
}
