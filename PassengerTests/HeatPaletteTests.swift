import Testing
import UIKit
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

    // MARK: - fillOpacity (T-038/PAS-29 acceptance REJECT, F1a)

    @Test("fillOpacity multiplies the band's own opacity by the dim factor; a dim of 1 is a no-op")
    func fillOpacityAppliesTheDimFactor() {
        for band in HeatBand.allCases {
            #expect(HeatPalette.fillOpacity(for: band, dimmedBy: 1) == HeatPalette.opacity(for: band))
            #expect(HeatPalette.fillOpacity(for: band, dimmedBy: 0.25) == HeatPalette.opacity(for: band) * 0.25)
        }
    }

    @Test(
        "a dimmed heat fill's rendered alpha is measurably weaker than the same band undimmed — the rendered colour, not the multiplier handed in (L-009)",
        arguments: [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark]
    )
    func dimmedFillRendersWeakerThanUndimmed(style: UIUserInterfaceStyle) {
        let trait = UITraitCollection(userInterfaceStyle: style)
        for band in HeatBand.allCases {
            let undimmedColor = HeatPalette.hue.opacity(HeatPalette.fillOpacity(for: band, dimmedBy: 1))
            let dimmedColor = HeatPalette.hue.opacity(HeatPalette.fillOpacity(for: band, dimmedBy: 0.25))
            let undimmedAlpha = UIColor(undimmedColor).resolvedColor(with: trait).cgColor.alpha
            let dimmedAlpha = UIColor(dimmedColor).resolvedColor(with: trait).cgColor.alpha
            #expect(
                dimmedAlpha < undimmedAlpha,
                "\(band) at \(style): dimmed alpha \(dimmedAlpha) was not weaker than undimmed \(undimmedAlpha)"
            )
        }
    }
}
