import Testing
@testable import Passenger

/// Covers search-quick-filters TRD §4.6 — `SearchSession` itself. The
/// seven-path completion/interruption table (§9 row 7) is covered against
/// `MapScreen`'s own wiring functions in `MapScreenSearchWiringTests`, not
/// here; this suite covers only the type's own two properties and its one
/// mutation.
@Suite("SearchSession")
@MainActor
struct SearchSessionTests {
    @Test("starts empty, filter .fresh")
    func startsEmpty() {
        let session = SearchSession()
        #expect(session.text.isEmpty)
        #expect(session.filter == .fresh)
    }

    @Test("clear() resets both text and filter, regardless of prior state")
    func clearResetsBoth() {
        let session = SearchSession()
        session.text = "florentin"
        session.filter = .only(.eatDrink)

        session.clear()

        #expect(session.text.isEmpty)
        #expect(session.filter == .fresh)
    }
}
