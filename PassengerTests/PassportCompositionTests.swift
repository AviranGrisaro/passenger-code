import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// passport TRD §9 rows 3/4, §11 C3/C4. `LocalStatus` and
/// `PassportComposition` are pure over value types, so the full fixture
/// matrix the TRD names — a designated-and-Local Hood, a designated-not-Local
/// Hood, an undesignated Hood, and (separately) an empty designated set — is
/// exercised with no simulator and no live `PlaceCatalog`/`VisitedPlacesStore`.
@Suite("LocalStatus")
struct LocalStatusTests {
    @Test("isLocal is beenCount >= threshold, nothing else")
    func isLocalMatchesThreshold() {
        #expect(LocalStatus.isLocal(beenCount: LocalStatus.threshold - 1) == false)
        #expect(LocalStatus.isLocal(beenCount: LocalStatus.threshold) == true)
        #expect(LocalStatus.isLocal(beenCount: LocalStatus.threshold + 1) == true)
    }

    @Test("zero is never Local, regardless of threshold")
    func zeroIsNeverLocal() {
        #expect(LocalStatus.isLocal(beenCount: 0) == false)
    }
}

@Suite("PassportComposition")
struct PassportCompositionTests {
    // MARK: - Fixtures

    private static let registry = PlaceTypeRegistry(resourceName: "place-types-test-fixture", bundle: Self.testBundle)
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

    private static func place(id: String, name: String, hoodID: String, placeType: String = "cafe") -> Place {
        Place(
            id: id, name: name, category: .eatDrink, hoodID: hoodID,
            coordinate: CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77),
            permanentlyClosed: false, placeType: placeType, isTouristTrap: nil
        )
    }

    private static func hood(id: String, name: String, designated: Bool) -> Hood {
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10), MKMapPoint(x: 0, y: 10)]
        let rect = MKMapRect(x: 0, y: 0, width: 10, height: 10)
        return Hood(
            id: id, name: name, ring: ring, boundingRect: rect,
            centroid: MKMapPoint(x: 5, y: 5).coordinate, blurb: nil, isTouristTrap: nil,
            designatedForProgression: designated
        )
    }

    // MARK: - stickers (§9 row 3)

    @Test("exactly one sticker per Been place; Visited, Saved-only, and unsourced places earn none")
    func stickersOnlyForBeenPlaces() {
        let been = Self.place(id: "been", name: "Been Place", hoodID: "a")
        let visited = Self.place(id: "visited", name: "Visited Place", hoodID: "a")
        let unsourced = Self.place(id: "unsourced", name: "Unsourced Place", hoodID: "a")
        let places = [been, visited, unsourced]
        let visits: [Place.ID: VisitKind] = [been.id: .been, visited.id: .visited]

        let stickers = PassportComposition.stickers(places: places, visits: visits, registry: Self.registry)

        #expect(stickers.map(\.place.id) == ["been"])
    }

    @Test("a revisit (already Been) still yields exactly one sticker — visits holds at most one kind per place")
    func revisitAddsNoDuplicate() {
        let been = Self.place(id: "been", name: "Been Place", hoodID: "a")
        let stickers = PassportComposition.stickers(
            places: [been], visits: [been.id: .been], registry: Self.registry
        )
        #expect(stickers.count == 1)
    }

    @Test("a visit id with no matching Place is skipped, not defaulted, and never crashes")
    func unresolvableVisitIDIsSkipped() {
        let been = Self.place(id: "been", name: "Been Place", hoodID: "a")
        let stickers = PassportComposition.stickers(
            places: [been], visits: [been.id: .been, "ghost-place": .been], registry: Self.registry
        )
        #expect(stickers.map(\.place.id) == ["been"])
    }

    @Test("shape matches the registered place_type; an unregistered place_type degrades to .generic, never dropped")
    func shapeResolvesFromRegistry() {
        let registered = Self.place(id: "a", name: "A", hoodID: "h", placeType: "cafe")
        let unregistered = Self.place(id: "b", name: "B", hoodID: "h", placeType: "does-not-exist")
        let stickers = PassportComposition.stickers(
            places: [registered, unregistered],
            visits: [registered.id: .been, unregistered.id: .been],
            registry: Self.registry
        )
        #expect(stickers.first { $0.place.id == "a" }?.shape != .generic)
        #expect(stickers.first { $0.place.id == "b" }?.shape == .generic)
    }

    @Test("output is name-ascending, id-tiebroken, and deterministic across runs")
    func stickersAreDeterministicallyOrdered() {
        let places = [
            Self.place(id: "z1", name: "Match", hoodID: "a"),
            Self.place(id: "a1", name: "Apple", hoodID: "a"),
            Self.place(id: "m2", name: "Match", hoodID: "a"),
            Self.place(id: "m1", name: "Match", hoodID: "a"),
        ]
        let visits = Dictionary(uniqueKeysWithValues: places.map { ($0.id, VisitKind.been) })

        let first = PassportComposition.stickers(places: places, visits: visits, registry: Self.registry)
        let second = PassportComposition.stickers(places: places.shuffled(), visits: visits, registry: Self.registry)

        #expect(first.map(\.place.id) == ["a1", "m1", "m2", "z1"])
        #expect(second.map(\.place.id) == first.map(\.place.id))
    }

    // MARK: - progress (§9 row 4)

    @Test("undesignated Hoods are absent from the output entirely, never present at zero")
    func undesignatedHoodsAreAbsent() {
        let designated = Self.hood(id: "d", name: "Designated", designated: true)
        let undesignated = Self.hood(id: "u", name: "Undesignated", designated: false)
        let progress = PassportComposition.progress(hoods: [designated, undesignated], places: [], visits: [:])
        #expect(progress.map(\.hood.id) == ["d"])
    }

    @Test("beenCount only counts Been places in that Hood — Visited and Saved-only don't add, other Hoods don't add")
    func beenCountIsScopedToTheHood() {
        let hoodA = Self.hood(id: "a", name: "A", designated: true)
        let hoodB = Self.hood(id: "b", name: "B", designated: true)
        let beenInA = Self.place(id: "been-a", name: "Been A", hoodID: "a")
        let visitedInA = Self.place(id: "visited-a", name: "Visited A", hoodID: "a")
        let beenInB = Self.place(id: "been-b", name: "Been B", hoodID: "b")
        let places = [beenInA, visitedInA, beenInB]
        let visits: [Place.ID: VisitKind] = [beenInA.id: .been, visitedInA.id: .visited, beenInB.id: .been]

        let progress = PassportComposition.progress(hoods: [hoodA, hoodB], places: places, visits: visits)

        #expect(progress.first { $0.hood.id == "a" }?.beenCount == 1)
        #expect(progress.first { $0.hood.id == "b" }?.beenCount == 1)
    }

    @Test("progress rows are name-ascending, id-tiebroken")
    func progressIsDeterministicallyOrdered() {
        let hoods = [
            Self.hood(id: "z", name: "Zebra Hood", designated: true),
            Self.hood(id: "a", name: "Apple Hood", designated: true),
        ]
        let progress = PassportComposition.progress(hoods: hoods, places: [], visits: [:])
        #expect(progress.map(\.hood.id) == ["a", "z"])
    }

    // MARK: - isOverallLocal (§9 row 4)

    @Test("false when the designated set is empty — an empty allSatisfy must not read as Local everywhere")
    func emptyDesignatedSetIsNeverOverallLocal() {
        #expect(PassportComposition.isOverallLocal([]) == false)
    }

    @Test("true only when every designated Hood is Local")
    func overallLocalRequiresEveryHood() {
        let allLocal = [
            HoodProgress(hood: Self.hood(id: "a", name: "A", designated: true), beenCount: LocalStatus.threshold),
            HoodProgress(hood: Self.hood(id: "b", name: "B", designated: true), beenCount: LocalStatus.threshold),
        ]
        let oneNotLocal = [
            HoodProgress(hood: Self.hood(id: "a", name: "A", designated: true), beenCount: LocalStatus.threshold),
            HoodProgress(hood: Self.hood(id: "b", name: "B", designated: true), beenCount: 0),
        ]
        #expect(PassportComposition.isOverallLocal(allLocal) == true)
        #expect(PassportComposition.isOverallLocal(oneNotLocal) == false)
    }
}
