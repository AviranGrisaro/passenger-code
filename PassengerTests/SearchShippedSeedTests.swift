import Testing
@testable import Passenger

/// Exercises `SearchQuery`/`SearchIndex` against the real shipped
/// `places-tel-aviv.json` + `hoods-tel-aviv.json` — TRD §9 row 2's exact
/// probes, run against the actual Phase-1 data rather than a synthetic
/// fixture (same "hosted test target reads the real bundle" property
/// `PlaceCatalogTests`'s shipped-bundle tests rely on).
///
/// **Two of §9 row 2's expected values do not hold against the real shipped
/// seed and this task's own §4.4 matching algorithm — recorded here as
/// found, not silently "fixed" by asserting the TRD's numbers:**
///
/// - Row 2(b) expects `run("shakshuka", …)` to return `["Dr. Shakshuka"]`
///   "with `matchedKeyword` set." But `"Dr. Shakshuka"`'s own *name*
///   contains `"shakshuka"` — §4.4 rule 4's tie-break ("name match wins
///   over keyword match for the same place") makes this a name match,
///   `matchedKeyword == nil`, by the TRD's own literal algorithm. Asserted
///   below as the algorithm actually and correctly produces.
/// - Row 2(c) expects `run("Florentin", …)` to return "exactly one result,
///   kind == .hood." But the seed also carries a *place* named "Florentin
///   Street Art Walk," whose name also contains "Florentin" — the correct
///   result per §4.4/D7 is two rows (the Hood, then that place), not one.
///
/// Both are almost certainly the TRD author computing expected values
/// without cross-checking them against the real seed's place names, not a
/// bug in the matcher. Flagged for `architect`/`qa` at review rather than
/// silently building a matcher that special-cases either place to hit the
/// TRD's literal numbers.
@Suite("SearchQuery against the shipped Tel Aviv seed")
@MainActor
struct SearchShippedSeedTests {
    private static func loadedIndex() async -> SearchIndex {
        let catalog = PlaceCatalog()
        await catalog.load()
        let hoods = (try? HoodCatalog.load()) ?? []
        return SearchIndex.build(places: catalog.allPlaces, hoods: hoods)
    }

    @Test("§9 row 2(a): \"suzan\" returns both Suzana/Suzanne places, name-ascending, no Hoods")
    func rowTwoA() async {
        let index = await Self.loadedIndex()
        let results = SearchQuery.run("suzan", filter: .all, in: index)
        #expect(results.map(\.displayName) == ["Suzana Yemenite Kitchen", "Suzanne Restaurant"])
        #expect(results.allSatisfy { if case .place = $0.kind { true } else { false } })
    }

    @Test("§9 row 2(b), as the algorithm actually resolves it: \"shakshuka\" is a NAME match (matchedKeyword nil), not a keyword match")
    func rowTwoBShakshuka() async {
        let index = await Self.loadedIndex()
        let results = SearchQuery.run("shakshuka", filter: .all, in: index)
        #expect(results.map(\.displayName) == ["Dr. Shakshuka"])
        guard case .place(_, let matchedKeyword) = results[0].kind else {
            Issue.record("expected a place result")
            return
        }
        // See file header: §9 row 2(b) says "matchedKeyword set" — the name
        // literally contains "shakshuka," so §4.4's own tie-break makes this
        // nil. This assertion documents the actual, correct behavior.
        #expect(matchedKeyword == nil)
    }

    @Test("§9 row 2(b): \"coffee\" is a genuine keyword match on HaMakolet")
    func rowTwoBCoffee() async {
        let index = await Self.loadedIndex()
        let results = SearchQuery.run("coffee", filter: .all, in: index)
        #expect(results.map(\.displayName) == ["HaMakolet"])
        guard case .place(_, let matchedKeyword) = results[0].kind else {
            Issue.record("expected a place result")
            return
        }
        #expect(matchedKeyword == "coffee")
    }

    @Test("§9 row 2(c), as the algorithm actually resolves it: \"Florentin\" matches the Hood AND \"Florentin Street Art Walk\"")
    func rowTwoCFlorentin() async {
        let index = await Self.loadedIndex()
        let results = SearchQuery.run("Florentin", filter: .all, in: index)
        // See file header: §9 row 2(c) says "exactly one result, kind ==
        // .hood" — the seed also has a place whose name contains
        // "Florentin," so D7's ordering puts the Hood first and the place
        // second. This assertion documents the actual, correct behavior.
        #expect(results.map(\.displayName) == ["Florentin", "Florentin Street Art Walk"])
        #expect({ if case .hood = results[0].kind { true } else { false } }())
    }

    @Test("the strategy probe words \"hummus\"/\"rooftop bar\" are not in the Phase-1 seed (TRD §3.4) — not checkable here")
    func strategyProbeWordsAreNotInPhase1Seed() async {
        let index = await Self.loadedIndex()
        #expect(SearchQuery.run("hummus", filter: .all, in: index).isEmpty)
        #expect(SearchQuery.run("rooftop bar", filter: .all, in: index).isEmpty)
    }
}
