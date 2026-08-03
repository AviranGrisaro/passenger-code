import Testing
@testable import Passenger

/// TRD §4.7, §9 row 2a — the pure composition step, testable with no
/// `DensityStore`, no simulator.
@Suite("HeatComposition")
struct HeatCompositionTests {
    private static func hood(_ id: String) -> Hood {
        Hood(
            id: id, name: id, ring: [], boundingRect: .null,
            centroid: .init(latitude: 0, longitude: 0), blurb: nil, isTouristTrap: nil,
            designatedForProgression: false
        )
    }

    @Test("fills produces one entry per Hood, in the same order")
    func onePerHood() {
        let hoods = [Self.hood("florentin"), Self.hood("jaffa")]
        let fills = HeatComposition.fills(hoods: hoods, hour: 0) { _, _ in .quiet }
        #expect(fills.count == 2)
        #expect(fills.map(\.hood.id) == ["florentin", "jaffa"])
    }

    @Test("fills differs across two hours for the same Hood set — §9 row 2a's falsifiable check")
    func differsAcrossHours() {
        let hoods = [Self.hood("florentin")]
        let bandsByHour: [Int: HeatBand] = [0: .quiet, 1: .busy]
        let lookup: (String, Int) -> HeatBand? = { _, hour in bandsByHour[hour] }

        let fillsAtZero = HeatComposition.fills(hoods: hoods, hour: 0, band: lookup)
        let fillsAtOne = HeatComposition.fills(hoods: hoods, hour: 1, band: lookup)

        #expect(fillsAtZero != fillsAtOne)
        #expect(fillsAtZero.first?.band == .quiet)
        #expect(fillsAtOne.first?.band == .busy)
    }

    @Test("fills for the same hour twice is identical — a same-hour call is a no-op change")
    func identicalForTheSameHour() {
        let hoods = [Self.hood("florentin"), Self.hood("jaffa")]
        let lookup: (String, Int) -> HeatBand? = { id, _ in id == "florentin" ? .moderate : nil }

        let first = HeatComposition.fills(hoods: hoods, hour: 3, band: lookup)
        let second = HeatComposition.fills(hoods: hoods, hour: 3, band: lookup)

        #expect(first == second)
    }

    @Test("a nil band for a Hood/hour carries through as nil — silent-empty, never a default")
    func nilBandCarriesThrough() {
        let hoods = [Self.hood("old-north")]
        let fills = HeatComposition.fills(hoods: hoods, hour: 3) { _, _ in nil }
        #expect(fills.first?.band == nil)
    }

    /// TRD §4.7, §9 row 2b — the structural half of the <400ms budget: the
    /// composition step itself, over every one of the app's real 24 Hoods,
    /// resolves in a small fraction of the budget. This does not measure
    /// MapKit's own frame commit (no app code can observe that, §4.7's own
    /// honest-scope statement) — it measures the one step this task can
    /// actually name and bracket with `HeatRepaintSignpost`.
    @Test("resolving fills for all 24 real Hoods completes near-instantly")
    func resolvingAllHoodsIsFast() {
        let hoods = (0..<24).map { Self.hood("hood-\($0)") }
        let start = ContinuousClock.now
        _ = HeatComposition.fills(hoods: hoods, hour: 6) { _, hour in HeatBand(rawValue: (hour % 3) + 1) }
        let elapsed = ContinuousClock.now - start
        #expect(elapsed < .milliseconds(400))
    }
}
