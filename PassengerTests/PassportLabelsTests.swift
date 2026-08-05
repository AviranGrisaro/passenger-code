import Testing
@testable import Passenger

/// passport TRD §4.7, §9 row 7 — pure string composition, unit-tested over
/// the full matrix, no simulator and no VoiceOver session needed.
@Suite("PassportLabels")
struct PassportLabelsTests {
    // MARK: - sticker (D12: names the shape, never the raw place_type)

    @Test("names the place and the shape word — never the raw place_type", arguments: StickerShape.allCases)
    func stickerLabelNamesTheShape(shape: StickerShape) {
        let label = PassportLabels.sticker(placeName: "Dr. Shakshuka", shape: shape)
        #expect(label == "Dr. Shakshuka, \(shape.spokenName) sticker")
        // The literal `place_type` string this shape might have come from
        // ("restaurant", "cafe", ...) never appears unless it happens to
        // equal the shape's own spoken word — checked structurally by
        // construction, not by string search, since `spokenName` is a
        // closed vocabulary distinct from `place_type`.
    }

    @Test("the TRD's own worked example (amended v3, §9 row 7(a) — depiction, never a geometry word)")
    func trdExample() {
        let label = PassportLabels.sticker(placeName: "Dr. Shakshuka", shape: .cutlery)
        #expect(label == "Dr. Shakshuka, cutlery sticker")
    }

    // MARK: - hoodProgress (count + Local state, always both)

    @Test(
        "names the Hood, the count against the threshold, and whether Local is reached",
        arguments: [(2, 2, true), (0, 2, false), (1, 2, false)]
    )
    func hoodProgressStatesCountAndLocal(beenCount: Int, threshold: Int, isLocal: Bool) {
        let label = PassportLabels.hoodProgress(
            hoodName: "Kerem HaTeimanim", beenCount: beenCount, threshold: threshold, isLocal: isLocal
        )
        let expectedStatus = isLocal ? "Local reached" : "not yet Local"
        #expect(label == "Kerem HaTeimanim, \(beenCount) of \(threshold) places, \(expectedStatus)")
    }

    @Test("the TRD's own worked examples")
    func trdWorkedExamples() {
        #expect(
            PassportLabels.hoodProgress(hoodName: "Kerem HaTeimanim", beenCount: 2, threshold: 2, isLocal: true)
                == "Kerem HaTeimanim, 2 of 2 places, Local reached"
        )
        #expect(
            PassportLabels.hoodProgress(hoodName: "Florentin", beenCount: 0, threshold: 2, isLocal: false)
                == "Florentin, 0 of 2 places, not yet Local"
        )
    }

    // MARK: - overall

    @Test("every designated Hood Local reads as 'every neighbourhood'")
    func overallEveryNeighbourhood() {
        #expect(PassportLabels.overall(localCount: 3, designatedCount: 3) == "Local in every neighbourhood")
    }

    @Test("a partial count reads as 'N of M neighbourhoods'")
    func overallPartial() {
        #expect(PassportLabels.overall(localCount: 1, designatedCount: 3) == "Local in 1 of 3 neighbourhoods")
    }

    @Test("zero designated Hoods never reads as 'every neighbourhood' — the one answer that must never render")
    func overallEmptyDesignatedSetNeverReadsAsEvery() {
        #expect(PassportLabels.overall(localCount: 0, designatedCount: 0) != "Local in every neighbourhood")
    }
}
