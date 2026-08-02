import Testing
@testable import Passenger

/// Covers places-been-saved TRD §3.3/§4.2 and §9 rows 3/5: the fixture
/// reader keeps the higher `VisitKind` on a duplicate `place_id`, a
/// missing/corrupt fixture never crashes, and `VisitedPlacesStore` has no
/// write path.
@Suite("BundledVisitSource")
struct BundledVisitSourceTests {
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }

    @Test("a duplicate place_id keeps the higher VisitKind and drops the other")
    func duplicateKeepsHigherKind() async {
        let source = BundledVisitSource(resourceName: "place-visits-test-fixture", bundle: Self.testBundle)
        let visits = await source.loadVisits()

        // Exactly one entry for the duplicated id — never two rows for one place.
        #expect(visits["dup-place"] == .been)
        #expect(visits["solo-been"] == .been)
        #expect(visits["solo-visited"] == .visited)
        #expect(visits.count == 3)
    }

    @Test("a missing fixture resource yields an empty dictionary, never a crash")
    func missingResourceIsEmpty() async {
        let source = BundledVisitSource(resourceName: "does-not-exist", bundle: Self.testBundle)
        let visits = await source.loadVisits()
        #expect(visits.isEmpty)
    }

    @Test("a malformed fixture (not the expected shape) yields an empty dictionary, never a crash")
    func malformedResourceIsEmpty() async {
        // `hoods-test-fixture` is real JSON but not a `VisitFile` shape —
        // proves the decode failure path, not just a missing file.
        let source = BundledVisitSource(resourceName: "hoods-test-fixture", bundle: Self.testBundle)
        let visits = await source.loadVisits()
        #expect(visits.isEmpty)
    }

    @Test("the shipped fixture authors at least one been and one visited entry, and at least one place in no source (TRD §3.3 authoring rule)")
    func shippedFixtureSatisfiesAuthoringRule() async {
        let source = BundledVisitSource()  // real bundle, real resource name
        let visits = await source.loadVisits()

        #expect(visits.values.contains(.been))
        #expect(visits.values.contains(.visited))
        // The shipped seed has 9 places; the fixture names 4 — proves at
        // least one place appears in no provenance source.
        #expect(visits.count < 9)
    }
}

private actor FakeVisitSource: VisitSourcing {
    private let result: [Place.ID: VisitKind]
    init(result: [Place.ID: VisitKind]) { self.result = result }
    func loadVisits() async -> [Place.ID: VisitKind] { result }
}

@Suite("VisitedPlacesStore")
@MainActor
struct VisitedPlacesStoreTests {
    @Test("starts empty before load()")
    func startsEmpty() {
        let store = VisitedPlacesStore(source: FakeVisitSource(result: [:]))
        #expect(store.visits.isEmpty)
    }

    @Test("load() populates visits from the source")
    func loadPopulatesFromSource() async {
        let store = VisitedPlacesStore(source: FakeVisitSource(result: ["a": .been]))
        await store.load()
        #expect(store.visits == ["a": .been])
    }
}
