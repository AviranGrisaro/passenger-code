import MapKit
import SwiftUI
import Testing
import UIKit
@testable import Passenger

/// Closes the coverage gap T-038/PAS-29's second acceptance pass named
/// directly: `grep -rn isDimmed PassengerTests/ PassengerUITests/` returned
/// zero hits before this file — nothing anywhere asserted a layer's dim
/// state. `HoodLayer.fillColor` is `internal`, not `private`, specifically
/// so this suite can read the rendered colour a real `isDimmed` value
/// produces, not just the boolean `MapScreen` hands in (L-009: the rendered
/// result, not the passed value).
///
/// F1a (T-038/PAS-29's second acceptance REJECT): `HoodLayer` dimmed its
/// polygon's stroke and centroid annotation but never its heat fill —
/// `foregroundStyle(fillColor)` ignored `dimOpacity` in all three
/// `effectiveStroke` branches, despite `HoodLayer`'s own doc comments
/// claiming otherwise. This suite would have failed against that code.
@Suite("HoodLayer fill dim (T-038/PAS-29 acceptance REJECT, F1a)")
struct HoodLayerFillDimTests {
    private static func hood(id: String) -> Hood {
        let ring = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 10, y: 0), MKMapPoint(x: 10, y: 10)]
        return Hood(
            id: id, name: id, ring: ring,
            boundingRect: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            centroid: MKMapPoint(x: 5, y: 5).coordinate,
            blurb: nil, isTouristTrap: nil, designatedForProgression: false
        )
    }

    @Test("a dimmed HoodLayer's fill renders a measurably weaker alpha than the same band undimmed, at every zoom tier")
    func dimmedFillIsWeakerThanUndimmed() {
        for zoomTier: MapZoomTier in [.cityWide, .neighborhood, .close] {
            for band in HeatBand.allCases {
                let undimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: band, zoomTier: zoomTier, isDimmed: false)
                let dimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: band, zoomTier: zoomTier, isDimmed: true)

                let undimmedAlpha = UIColor(undimmed.fillColor).cgColor.alpha
                let dimmedAlpha = UIColor(dimmed.fillColor).cgColor.alpha

                #expect(
                    dimmedAlpha < undimmedAlpha,
                    "\(zoomTier)/\(band): dimmed alpha \(dimmedAlpha) was not weaker than undimmed \(undimmedAlpha)"
                )
            }
        }
    }

    @Test("isDimmed false renders byte-identically to a HoodLayer with no dim concept at all — every pre-search caller is unaffected")
    func undimmedMatchesPlainFill() {
        for band in HeatBand.allCases {
            let layer = HoodLayer(hood: Self.hood(id: "florentin"), band: band, zoomTier: .cityWide, isDimmed: false)
            #expect(layer.fillColor == HeatPalette.fill(for: band))
        }
    }

    @Test("a Hood with no density band stays fully clear whether dimmed or not — dimming a transparent fill has nothing to multiply")
    func noBandStaysClearRegardlessOfDim() {
        let undimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: nil, zoomTier: .cityWide, isDimmed: false)
        let dimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: nil, zoomTier: .cityWide, isDimmed: true)

        #expect(undimmed.fillColor == Color.clear)
        #expect(dimmed.fillColor == Color.clear)
    }
}
