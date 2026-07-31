import Testing
@testable import Passenger

/// Covers D4 (`hood-place-detail/TRD.md`): `displayName` is the only place a
/// user-facing category string exists, and both cases must render the exact
/// approved copy — not the retired "Food & drinks" wording.
@Suite("PlaceCategory")
struct PlaceCategoryTests {
    @Test("both cases render their approved display string")
    func displayStrings() {
        #expect(PlaceCategory.eatDrink.displayName == "Eat & Drink")
        #expect(PlaceCategory.thingsToDo.displayName == "Things to do")
    }
}
