import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers search-quick-filters TRD §4.10 — `SearchDim.emphasis`.
@Suite("SearchDim")
struct SearchDimTests {
    private static func place(id: String) -> Place {
        Place(
            id: id, name: id, category: .eatDrink, hoodID: "florentin",
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

    @Test("a mix of place and Hood results emphasises exactly those ids, each other's set untouched")
    func mixedResultsEmphasisesExactSets() {
        let results: [SearchResult] = [
            .hood(Self.hood(id: "florentin")),
            .place(Self.place(id: "cafe"), matchedKeyword: nil, hoodName: "Florentin"),
        ]
        let emphasis = SearchDim.emphasis(results: results)
        #expect(emphasis?.hoods == ["florentin"])
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
}
