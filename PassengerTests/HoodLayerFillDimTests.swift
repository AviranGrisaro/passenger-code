import MapKit
import SwiftUI
import Testing
import UIKit
@testable import Passenger

/// Retargeted at v3 (T-038/`PAS-55`, C15) — `PAS-49` (`passenger-code c1b8bc3`/
/// `5e1f72f`) rewrote `HoodLayer.body` to draw `.foregroundStyle(.clear)` in
/// every stroke branch, so `fillColor` stopped being the channel `body`
/// renders. This suite's original assertions (below, kept as a cheap
/// regression guard per D15 — they still prove `fillColor` computes
/// correctly, just not that anything draws it) stayed green throughout that
/// change and proved nothing about the render, which is exactly L-009's
/// failure shape a third time. The render channel is `borderColor`
/// (`HoodLayer.swift`), which is what the new tests below assert, per
/// search-quick-filters TRD §9 row 4 (a)/(b)/(f).
///
/// `grep -rn borderColor PassengerTests/ PassengerUITests/` returned zero
/// hits before this file was rewritten — the TRD's coverage-anchor rule
/// (§9 preamble, third standing rule) requires that grep be re-run and
/// positive before these assertions are trusted; it is, once this file
/// exists. `HoodLayer.borderColor` is `internal`, not `private`, specifically
/// so this suite can read the rendered colour a real `isDimmed` value
/// produces, not just the boolean `MapScreen` hands in (L-009).
@Suite("HoodLayer border dim (T-038/PAS-55, C15 — retargeted from fillColor, the channel body no longer draws)")
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

    // MARK: - borderColor (the rendered channel, §9 row 4 (a)/(b)/(f))

    /// Row 4(a): the exact 0.25 ratio, not just "strictly less" — an
    /// inequality passes against a floored or clamped multiplier, the ratio
    /// doesn't. Every `HeatBand` gets a fixture (row 4(a)(ii): `borderColor`
    /// clamps at `min(bandStrength * hoverGlow, 1)`, so a single-band
    /// fixture can't tell a correct multiply from a clamped one), plus the
    /// `nil` band, so every band `HoodLayer` can be constructed with is
    /// covered — at least one Hood per band, per the TRD's fixture
    /// condition (ii). `isHovered` is passed explicitly as `false` on every
    /// layer rather than left to the initializer default, per fixture
    /// condition (i): `hoverGlow`'s 1.4 multiplier is a second uncontrolled
    /// input to this same alpha, and this suite controls it rather than
    /// relying on a default that could change.
    ///
    /// `borderColor` doesn't vary with `zoomTier` — it's independent of it
    /// in `HoodLayer`'s implementation — so one representative tier
    /// (`.neighborhood`) is sufficient here; `zoomTier`'s effect on which
    /// stroke variant `body` picks is a separate, already-covered concern
    /// (`effectiveStroke`), not this row.
    @Test("a dimmed HoodLayer's border renders exactly 0.25x its own undimmed border alpha, at every band including nil, isHovered pinned false")
    func dimmedBorderIsExactlyQuarterOfUndimmed() {
        let tolerance = 0.001
        let bandsIncludingNil: [HeatBand?] = [nil] + HeatBand.allCases

        for band in bandsIncludingNil {
            let undimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: band, zoomTier: .neighborhood, isDimmed: false, isHovered: false)
            let dimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: band, zoomTier: .neighborhood, isDimmed: true, isHovered: false)

            let undimmedAlpha = UIColor(undimmed.borderColor).cgColor.alpha
            let dimmedAlpha = UIColor(dimmed.borderColor).cgColor.alpha

            #expect(undimmedAlpha > 0, "band \(String(describing: band)): undimmed border alpha was 0 — nothing to take a ratio of")

            let ratio = dimmedAlpha / undimmedAlpha
            #expect(
                abs(ratio - 0.25) < tolerance,
                "band \(String(describing: band)): dimmed/undimmed border ratio was \(ratio), not 0.25 (dimmed \(dimmedAlpha), undimmed \(undimmedAlpha))"
            )
        }
    }

    /// Row 4(b): once a result is deselected or the sheet is dismissed,
    /// `isDimmed` goes back to `false` and the border's resolved alpha must
    /// return to exactly its no-search value — asserted here as the
    /// rendered readback, not just `isDimmed == false` as the cause (the
    /// TRD's own distinction: `emphasis == nil` is checked as the cause
    /// elsewhere, never as the evidence).
    @Test("isDimmed false renders a border byte-identical to a HoodLayer with no dim concept at all — every pre-search caller, and every un-dim after search, is unaffected")
    func undimmedBorderMatchesNoSearchConcept() {
        for band in HeatBand.allCases {
            let noDimConcept = HoodLayer(hood: Self.hood(id: "florentin"), band: band, zoomTier: .neighborhood, isDimmed: false, isHovered: false)
            let afterUnDim = HoodLayer(hood: Self.hood(id: "florentin"), band: band, zoomTier: .neighborhood, isDimmed: false, isHovered: false)

            #expect(
                UIColor(noDimConcept.borderColor).cgColor.alpha == UIColor(afterUnDim.borderColor).cgColor.alpha,
                "band \(band): a HoodLayer built with isDimmed: false does not match another built the same way — borderColor should be a pure function of its inputs"
            )
        }
    }

    /// Row 4(f), the one v2/v3 corrected rather than just retargeted: a
    /// `nil`-band Hood is **not** invisible. It renders a real neutral
    /// `.secondary` hairline at `0.35 * dimOpacity` — a check that expected
    /// "nothing renders" here would fail a *correct* implementation, per
    /// §4.10. This is distinct from `fillColor`, which does go fully
    /// `.clear` for a `nil` band (asserted below as the regression guard) —
    /// the two channels disagree on purpose now that the border, not the
    /// fill, is what `body` draws.
    ///
    /// `UIColor(Color.secondary.opacity(x))` is the TRD's named fragility:
    /// if this assertion ever stops resolving to a comparable alpha (e.g. a
    /// future SDK changes how a semantic color converts outside a live view
    /// hierarchy), that is a reason to mark this row BLOCKED/manual, not to
    /// weaken or delete the assertion. As run here, it resolves fine.
    @Test("a nil-band Hood's border is a visible neutral .secondary hairline, not .clear — the emphasis-absence limit (TRD §4.10) is about colour, not visibility")
    func nilBandBorderIsVisibleNeutralHairlineNotClear() {
        let undimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: nil, zoomTier: .neighborhood, isDimmed: false, isHovered: false)
        let dimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: nil, zoomTier: .neighborhood, isDimmed: true, isHovered: false)

        let undimmedAlpha = UIColor(undimmed.borderColor).cgColor.alpha
        let dimmedAlpha = UIColor(dimmed.borderColor).cgColor.alpha

        #expect(undimmedAlpha > 0, "nil-band border rendered fully transparent — TRD §4.10 requires a visible neutral hairline, not nothing")
        #expect(dimmedAlpha > 0, "nil-band border went fully transparent once dimmed — it should dim to 0.25x, not to nothing")
        #expect(undimmed.fillColor == .clear, "fillColor stays .clear for a nil band — unaffected by the border-only render, kept as the regression guard D15 names")
        #expect(dimmed.fillColor == .clear, "fillColor stays .clear for a nil band even when dimmed — dimming a transparent fill has nothing to multiply")
    }

    // MARK: - fillColor (kept as a cheap regression guard, D15 — not evidence about the render)

    /// D15: `fillColor` is dead code as far as `body` is concerned, but it
    /// still computes correctly and is cheap to keep asserting so a future
    /// change to `HeatPalette.fillOpacity` doesn't silently break *if*
    /// `fillColor` is ever wired back up. These three tests are the original
    /// suite's, unchanged — they no longer carry §9 row 4 (borderColor does),
    /// but they're kept per C15's explicit instruction not to delete them.
    @Test("[regression guard, not evidence] a dimmed HoodLayer's fill computes a measurably weaker alpha than the same band undimmed, at every zoom tier")
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

    @Test("[regression guard, not evidence] isDimmed false computes a fillColor byte-identical to a HoodLayer with no dim concept at all")
    func undimmedMatchesPlainFill() {
        for band in HeatBand.allCases {
            let layer = HoodLayer(hood: Self.hood(id: "florentin"), band: band, zoomTier: .cityWide, isDimmed: false)
            #expect(layer.fillColor == HeatPalette.fill(for: band))
        }
    }

    @Test("[regression guard, not evidence] a Hood with no density band computes a fully clear fillColor whether dimmed or not")
    func noBandStaysClearRegardlessOfDim() {
        let undimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: nil, zoomTier: .cityWide, isDimmed: false)
        let dimmed = HoodLayer(hood: Self.hood(id: "florentin"), band: nil, zoomTier: .cityWide, isDimmed: true)

        #expect(undimmed.fillColor == Color.clear)
        #expect(dimmed.fillColor == Color.clear)
    }
}
