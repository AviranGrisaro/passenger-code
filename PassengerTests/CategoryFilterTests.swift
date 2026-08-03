import Testing
@testable import Passenger

/// Covers search-quick-filters TRD §4.5, D8 (§9 row 3).
@Suite("CategoryFilter")
struct CategoryFilterTests {
    @Test("exactly two categories exist — the whole reason a third chip is structurally impossible")
    func exactlyTwoCategories() {
        #expect(PlaceCategory.allCases.count == 2)
    }

    @Test(".fresh is .all — both chips active on a fresh open (PRD req 3)")
    func freshIsAll() {
        #expect(CategoryFilter.fresh == .all)
        #expect(CategoryFilter.fresh.isActive(.eatDrink))
        #expect(CategoryFilter.fresh.isActive(.thingsToDo))
    }

    @Test(".all reports every category active")
    func allIsActiveForBoth() {
        #expect(CategoryFilter.all.isActive(.eatDrink))
        #expect(CategoryFilter.all.isActive(.thingsToDo))
    }

    @Test(".only(c) reports active for c only")
    func onlyIsActiveForExactlyOne() {
        #expect(CategoryFilter.only(.eatDrink).isActive(.eatDrink))
        #expect(!CategoryFilter.only(.eatDrink).isActive(.thingsToDo))
    }

    @Test("toggling from .all selects exactly that category")
    func togglingFromAllSelects() {
        #expect(CategoryFilter.all.toggling(.eatDrink) == .only(.eatDrink))
    }

    @Test("toggling the already-selected chip returns to .all — there is no way to reach 'neither selected'")
    func togglingSelectedChipReturnsToAll() {
        #expect(CategoryFilter.only(.eatDrink).toggling(.eatDrink) == .all)
    }

    @Test("toggling the other chip while one is selected switches selection, never stacks")
    func togglingOtherChipSwitches() {
        #expect(CategoryFilter.only(.eatDrink).toggling(.thingsToDo) == .only(.thingsToDo))
    }
}
