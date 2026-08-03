import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers search-quick-filters TRD §4.10 — `SearchDim.emphasis`.
@Suite("SearchDim")
struct SearchDimTests {
    private static func place(id: String, hoodID: String = "florentin") -> Place {
        Place(
            id: id, name: id, category: .eatDrink, hoodID: hoodID,
            coordinate: CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77),
            permanentlyClosed: false, placeType: "cafe", isTouristTrap: nil, keywords: []
        )
    }

    private static func hood(id: String) -> Hood {
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10)]
        return Hood(
            id: id, name: id, ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false
        )
    }

    @Test("an empty result set emphasises nothing")
    func emptyResultsIsNil() {
        #expect(SearchDim.emphasis(results: []) == nil)
    }

    @Test("a mix of place and Hood results emphasises the Hood match, the place match, and the place's own (distinct) Hood")
    func mixedResultsEmphasisesExactSets() {
        let results: [SearchResult] = [
            .hood(Self.hood(id: "florentin")),
            .place(Self.place(id: "cafe", hoodID: "kerem-hateimanim"), matchedKeyword: nil, hoodName: "Kerem HaTeimanim"),
        ]
        let emphasis = SearchDim.emphasis(results: results)
        #expect(emphasis?.hoods == ["florentin", "kerem-hateimanim"])
        #expect(emphasis?.places == ["cafe"])
    }

    @Test("duplicate results for the same place collapse to one set member")
    func duplicatesCollapse() {
        let place = Self.place(id: "cafe")
        let results: [SearchResult] = [
            .place(place, matchedKeyword: nil, hoodName: "Florentin"),
            .place(place, matchedKeyword: "coffee", hoodName: "Florentin"),
        ]
        #expect(SearchDim.emphasis(results: results)?.places == ["cafe"])
    }

    // MARK: - F1b (T-038/PAS-29's second acceptance REJECT): a place-only
    // match must emphasise something even where `PlaceLayer` never renders a
    // pin (`.cityWide`/`.neighborhood` zoom, including the cold-open camera).

    @Test("a place-only match — zero Hood results, exactly the reported repro shape — still emphasises that place's own Hood")
    func placeOnlyMatchEmphasisesItsOwnHood() {
        let results: [SearchResult] = [
            .place(Self.place(id: "suzana", hoodID: "kerem-hateimanim"), matchedKeyword: nil, hoodName: "Kerem HaTeimanim"),
        ]
        let emphasis = SearchDim.emphasis(results: results)
        #expect(emphasis?.places == ["suzana"])
        #expect(emphasis?.hoods == ["kerem-hateimanim"])
    }

    @Test("two place matches in the same Hood collapse that Hood to one set member, same as a duplicate place would")
    func twoPlacesInSameHoodCollapseToOneHoodMember() {
        let results: [SearchResult] = [
            .place(Self.place(id: "cafe-one", hoodID: "florentin"), matchedKeyword: nil, hoodName: "Florentin"),
            .place(Self.place(id: "cafe-two", hoodID: "florentin"), matchedKeyword: nil, hoodName: "Florentin"),
        ]
        let emphasis = SearchDim.emphasis(results: results)
        #expect(emphasis?.places == ["cafe-one", "cafe-two"])
        #expect(emphasis?.hoods == ["florentin"])
    }
}
