import CoreLocation
import Testing
@testable import Passenger

/// Covers places-been-saved TRD §4.1/§4.3 and §9 rows 1–2: precedence is a
/// `max` over `PlaceProvenance`, `entries`/`isListed` always agree, sort is
/// deterministic, and an un-save never writes through to the visit source.
@Suite("PlaceProvenance / VisitKind")
struct PlaceProvenanceTests {
    @Test("Saved beats Been beats Visited")
    func ordering() {
        #expect(PlaceProvenance.saved > PlaceProvenance.been)
        #expect(PlaceProvenance.been > PlaceProvenance.visited)
        #expect(PlaceProvenance.saved > PlaceProvenance.visited)
    }

    @Test("a VisitKind can never resolve to .saved — the type has no such case")
    func visitKindCannotClaimSaved() {
        #expect(VisitKind.been.provenance == .been)
        #expect(VisitKind.visited.provenance == .visited)
    }
}

@Suite("PlacesListComposition")
struct PlacesListCompositionTests {
    private static func makePlace(id: String, name: String, closed: Bool = false) -> Place {
        Place(
            id: id, name: name, category: .eatDrink, hoodID: "florentin",
            coordinate: CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77),
            permanentlyClosed: closed, isTouristTrap: nil
        )
    }

    // MARK: - §9 row 1: one row per place, precedence, never none

    @Test("a place in all three sources appears once, as .saved")
    func allThreeSourcesYieldsSavedOnce() {
        let place = Self.makePlace(id: "a", name: "A")
        let entries = PlacesListComposition.entries(
            places: [place], saved: ["a"], visits: ["a": .been]
        )
        #expect(entries.count == 1)
        #expect(entries.first?.provenance == .saved)
    }

    @Test("a place with only a Been visit, not saved, appears once as .been")
    func beenOnlyPlaceIsBeen() {
        let place = Self.makePlace(id: "a", name: "A")
        let entries = PlacesListComposition.entries(places: [place], saved: [], visits: ["a": .been])
        #expect(entries.first?.provenance == .been)
    }

    @Test("a place with no provenance in any source produces no entry")
    func unlistedPlaceProducesNoEntry() {
        let place = Self.makePlace(id: "a", name: "A")
        let entries = PlacesListComposition.entries(places: [place], saved: [], visits: [:])
        #expect(entries.isEmpty)
    }

    @Test("output count equals distinct listed place count, never more than one row per place")
    func oneRowPerPlace() {
        let places = [
            Self.makePlace(id: "a", name: "A"), Self.makePlace(id: "b", name: "B"),
            Self.makePlace(id: "c", name: "C"),
        ]
        let entries = PlacesListComposition.entries(
            places: places, saved: ["a", "b"], visits: ["b": .been, "c": .visited]
        )
        #expect(entries.count == 3)
        #expect(Set(entries.map(\.id)).count == 3)
    }

    @Test("a saved or visited id with no matching Place is skipped, not an error")
    func unresolvableIDIsSkipped() {
        let place = Self.makePlace(id: "a", name: "A")
        let entries = PlacesListComposition.entries(
            places: [place], saved: ["a", "ghost"], visits: ["also-ghost": .been]
        )
        #expect(entries.map(\.id) == ["a"])
    }

    @Test("output order is name-ascending, id as tiebreak, identical across runs (D4)")
    func deterministicNameAscendingSort() {
        let places = [
            Self.makePlace(id: "z", name: "Zebra"),
            Self.makePlace(id: "a", name: "Apple"),
            Self.makePlace(id: "m2", name: "Match"),
            Self.makePlace(id: "m1", name: "Match"),
        ]
        let saved = Set(places.map(\.id))
        let first = PlacesListComposition.entries(places: places, saved: saved, visits: [:]).map(\.id)
        let second = PlacesListComposition.entries(places: places, saved: saved, visits: [:]).map(\.id)
        #expect(first == ["a", "m1", "m2", "z"])
        #expect(first == second)
    }

    // MARK: - §9 row 2: manual save/un-save and the visit source stays untouched

    @Test("un-saving a place with a Been entry drops it to .been rather than removing the row")
    func unsaveFallsToVisitEntry() {
        let place = Self.makePlace(id: "a", name: "A")
        let visits: [Place.ID: VisitKind] = ["a": .been]

        let whileSaved = PlacesListComposition.entries(places: [place], saved: ["a"], visits: visits)
        #expect(whileSaved.first?.provenance == .saved)

        // Un-save: remove from the saved set. The visit dictionary passed in
        // is the exact same value — nothing in this call can have written to
        // it, since `entries` takes it as an immutable parameter.
        let afterUnsave = PlacesListComposition.entries(places: [place], saved: [], visits: visits)
        #expect(afterUnsave.first?.provenance == .been)
        #expect(visits == ["a": .been])  // byte-identical before and after
    }

    @Test("un-saving a place with no visit entry removes the row entirely")
    func unsaveWithNoVisitRemovesRow() {
        let place = Self.makePlace(id: "a", name: "A")
        let afterUnsave = PlacesListComposition.entries(places: [place], saved: [], visits: [:])
        #expect(afterUnsave.isEmpty)
    }

    // MARK: - isListed agreement (§9 row 7)

    @Test("isListed agrees with entries on every place, including the one in no source")
    func isListedAgreesWithEntries() {
        let places = [
            Self.makePlace(id: "a", name: "A"), Self.makePlace(id: "b", name: "B"),
            Self.makePlace(id: "c", name: "C"),
        ]
        let saved: Set<Place.ID> = ["a"]
        let visits: [Place.ID: VisitKind] = ["b": .visited]
        let entryIDs = Set(PlacesListComposition.entries(places: places, saved: saved, visits: visits).map(\.id))

        for place in places {
            let expected = entryIDs.contains(place.id)
            #expect(PlacesListComposition.isListed(place.id, saved: saved, visits: visits) == expected)
        }
    }
}
