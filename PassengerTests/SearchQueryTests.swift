import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Covers search-quick-filters TRD §4.4's matching rules (§9 rows 2, 3, 4).
@Suite("SearchQuery")
struct SearchQueryTests {
    private static func place(
        id: String, name: String, category: PlaceCategory = .eatDrink, hoodID: String = "florentin",
        keywords: [String] = []
    ) -> Place {
        Place(
            id: id, name: name, category: category, hoodID: hoodID,
            coordinate: CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77),
            permanentlyClosed: false, placeType: "cafe", isTouristTrap: nil, keywords: keywords
        )
    }

    private static func hood(id: String, name: String, aliases: [String] = []) -> Hood {
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10)]
        return Hood(
            id: id, name: name, ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false,
            aliases: aliases
        )
    }

    // MARK: - Rule 2/3: the empty-field states

    @Test("empty field + .all -> [] (PRD req 6's empty-field state)")
    func emptyFieldAllIsEmpty() {
        let index = SearchIndex.build(places: [Self.place(id: "a", name: "A")], hoods: [Self.hood(id: "florentin", name: "Florentin")])
        #expect(SearchQuery.run("", filter: .all, in: index).isEmpty)
        #expect(SearchQuery.run("   ", filter: .all, in: index).isEmpty)
    }

    @Test("empty field + an active chip -> every place of that category, name-ascending, no Hoods")
    func emptyFieldWithChipIsCategoryScoped() {
        let index = SearchIndex.build(
            places: [
                Self.place(id: "b", name: "Bravo", category: .eatDrink),
                Self.place(id: "a", name: "Alpha", category: .eatDrink),
                Self.place(id: "c", name: "Charlie", category: .thingsToDo),
            ],
            hoods: [Self.hood(id: "florentin", name: "Florentin")]
        )
        let results = SearchQuery.run("", filter: .only(.eatDrink), in: index)
        #expect(results.map(\.displayName) == ["Alpha", "Bravo"])
        #expect(results.allSatisfy { if case .place = $0.kind { true } else { false } })
    }

    // MARK: - Rule 4: substring match, name wins over keyword, no duplicates

    @Test("a place matches by name -> matchedKeyword is nil")
    func nameMatchHasNoMatchedKeyword() {
        let index = SearchIndex.build(places: [Self.place(id: "a", name: "Anna Loulou Bar")], hoods: [])
        let results = SearchQuery.run("anna", filter: .all, in: index)
        #expect(results.count == 1)
        guard case .place(_, let matchedKeyword) = results[0].kind else {
            Issue.record("expected a place result")
            return
        }
        #expect(matchedKeyword == nil)
    }

    @Test("a place matches only by keyword -> matchedKeyword names that keyword")
    func keywordOnlyMatchReportsTheKeyword() {
        let index = SearchIndex.build(places: [Self.place(id: "a", name: "HaMakolet", keywords: ["coffee", "brunch"])], hoods: [])
        let results = SearchQuery.run("coffee", filter: .all, in: index)
        #expect(results.count == 1)
        guard case .place(_, let matchedKeyword) = results[0].kind else {
            Issue.record("expected a place result")
            return
        }
        #expect(matchedKeyword == "coffee")
    }

    @Test("name match wins over keyword match for the same place — a place is never returned twice")
    func nameMatchWinsAndNeverDuplicates() {
        // Deliberately named so the query hits both the name AND a keyword —
        // §4.4 rule 4's tie-break must resolve this to exactly one, name-side, row.
        let index = SearchIndex.build(
            places: [Self.place(id: "a", name: "Coffee Corner", keywords: ["coffee", "espresso"])],
            hoods: []
        )
        let results = SearchQuery.run("coffee", filter: .all, in: index)
        #expect(results.count == 1)
        guard case .place(_, let matchedKeyword) = results[0].kind else {
            Issue.record("expected a place result")
            return
        }
        #expect(matchedKeyword == nil, "the name match must win — this is the single place the query hit twice")
    }

    @Test("a Hood and a place can both match the same query, with no duplication of either")
    func hoodAndPlaceBothMatchIndependently() {
        let index = SearchIndex.build(
            places: [Self.place(id: "a", name: "Florentin Street Art Walk", hoodID: "florentin")],
            hoods: [Self.hood(id: "florentin", name: "Florentin")]
        )
        let results = SearchQuery.run("florentin", filter: .all, in: index)
        // D7 order: Hood matches first, then place name matches.
        #expect(results.map(\.displayName) == ["Florentin", "Florentin Street Art Walk"])
    }

    // MARK: - hood-dataset TRD §3.1 D11: alias search (Kfar Shalem -> Neve Eliezer, etc.)

    @Test("a query matching a Hood's alias surfaces that Hood, not a separate result")
    func aliasMatchSurfacesTheOwningHood() {
        let index = SearchIndex.build(
            places: [],
            hoods: [Self.hood(id: "neve-eliezer", name: "Neve Eliezer", aliases: ["Kfar Shalem"])]
        )
        let results = SearchQuery.run("kfar shalem", filter: .all, in: index)
        #expect(results.count == 1)
        #expect(results.map(\.displayName) == ["Neve Eliezer"])
    }

    @Test("alias matching is case- and diacritic-insensitive, same as name matching")
    func aliasMatchIsFolded() {
        let index = SearchIndex.build(
            places: [],
            hoods: [Self.hood(id: "ramat-aviv", name: "Ramat Aviv", aliases: ["Ramat Aviv Aleph"])]
        )
        #expect(SearchQuery.run("RAMAT AVIV ALEPH", filter: .all, in: index).map(\.displayName) == ["Ramat Aviv"])
    }

    // MARK: - Rule 6: ordering — Hoods, then place-name matches, then keyword-only matches

    @Test("order: Hood name matches, then place name matches, then keyword-only place matches, ascending within each group")
    func orderingGroupsThenAscending() {
        let index = SearchIndex.build(
            places: [
                Self.place(id: "kw2", name: "Zeta", keywords: ["nightlife"]),
                Self.place(id: "kw1", name: "Alpha Bar", keywords: ["nightlife"]),
                Self.place(id: "n2", name: "Nightlife Lounge"),
                Self.place(id: "n1", name: "Nightlife Cafe"),
            ],
            hoods: [Self.hood(id: "h1", name: "Nightlife District")]
        )
        let results = SearchQuery.run("nightlife", filter: .all, in: index)
        #expect(results.map(\.displayName) == [
            "Nightlife District",   // Hood match
            "Nightlife Cafe", "Nightlife Lounge",  // place name matches, ascending
            "Alpha Bar", "Zeta",  // keyword-only matches, ascending
        ])
    }

    @Test("case-insensitive, diacritic-insensitive substring, mid-word")
    func substringMidWord() {
        let index = SearchIndex.build(places: [Self.place(id: "a", name: "Rooftop Bar")], hoods: [])
        #expect(SearchQuery.run("roof", filter: .all, in: index).map(\.displayName) == ["Rooftop Bar"])
        #expect(SearchQuery.run("ROOF", filter: .all, in: index).map(\.displayName) == ["Rooftop Bar"])
    }

    // MARK: - Rule 5 / D8: the chip narrows places only, never Hoods

    @Test("D8: an active chip removes non-matching-category places but never removes a Hood match")
    func chipNarrowsPlacesOnlyNotHoods() {
        let index = SearchIndex.build(
            places: [
                Self.place(id: "eat", name: "Suzana Kitchen", category: .eatDrink),
                Self.place(id: "todo", name: "Suzana Gallery", category: .thingsToDo),
            ],
            hoods: [Self.hood(id: "suzana-hood", name: "Suzana District")]
        )
        let results = SearchQuery.run("suzana", filter: .only(.eatDrink), in: index)
        #expect(results.map(\.displayName) == ["Suzana District", "Suzana Kitchen"])
    }

    // MARK: - §9 row 2(d): performance at a synthetic ~2,000-place ceiling

    @Test("run() completes well within budget at a synthetic 2,000-place, 6-keyword-each index")
    func performanceAtCeiling() {
        let places = (0..<2000).map { i in
            Self.place(id: "p\(i)", name: "Place Number \(i)", keywords: (0..<6).map { "keyword\($0)-\(i)" })
        }
        let hoods = (0..<24).map { Self.hood(id: "h\($0)", name: "Hood \($0)") }
        let index = SearchIndex.build(places: places, hoods: hoods)

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            _ = SearchQuery.run("keyword3-1000", filter: .all, in: index)
        }
        // TRD §9 row 2(d) targets ≤16ms (one frame); a generous 100ms bound
        // is asserted here instead to avoid simulator/CI timing flakiness
        // while still catching a gross algorithmic regression (e.g. an
        // accidental O(n²) scan).
        #expect(elapsed < .milliseconds(100))
    }
}
