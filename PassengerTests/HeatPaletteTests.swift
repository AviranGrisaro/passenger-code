import Testing
@testable import Passenger

@Suite("HeatPalette")
struct HeatPaletteTests {
    @Test("opacity strictly increases with band severity")
    func opacityIncreasesWithSeverity() {
        #expect(HeatPalette.opacity(for: .quiet) < HeatPalette.opacity(for: .moderate))
        #expect(HeatPalette.opacity(for: .moderate) < HeatPalette.opacity(for: .busy))
    }

    @Test("every opacity step is a valid, visible alpha value")
    func opacityStaysInValidRange() {
        for band in HeatBand.allCases {
            let opacity = HeatPalette.opacity(for: band)
            #expect(opacity > 0 && opacity <= 1)
        }
    }
}
