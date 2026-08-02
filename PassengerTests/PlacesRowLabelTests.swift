import Testing
@testable import Passenger

/// Full 3 (provenance) × 2 (closed/not) matrix, per places-been-saved TRD
/// §4.8 — pure and unit-tested with no simulator, no VoiceOver session
/// needed to prove the strings.
@Suite("PlacesRowLabel")
struct PlacesRowLabelTests {
    @Test(
        "name, category, provenance word, and — only when closed — a trailing 'permanently closed' clause",
        arguments: PlaceProvenance.allCases, [false, true]
    )
    func fullMatrix(provenance: PlaceProvenance, isClosed: Bool) {
        let label = PlacesRowLabel.label(name: "Nachum Gutman Museum", category: .thingsToDo, provenance: provenance, isClosed: isClosed)

        var expectedClauses = ["Nachum Gutman Museum", "Things to do", provenance.word]
        if isClosed {
            expectedClauses.append("permanently closed")
        }
        #expect(label == expectedClauses.joined(separator: ", "))
    }

    @Test("the TRD's own worked example")
    func trdExample() {
        let label = PlacesRowLabel.label(name: "Nachum Gutman Museum", category: .thingsToDo, provenance: .visited, isClosed: true)
        #expect(label == "Nachum Gutman Museum, Things to do, Visited, permanently closed")
    }
}
