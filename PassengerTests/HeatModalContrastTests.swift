import Testing
import UIKit
@testable import Passenger

/// TRD §4.12, §9 row 6d. Same construction as `PlacesListContrastTests`/
/// `FlagContrastTests`: resolves the real Asset Catalog color sets under
/// real light/dark trait collections, never a hardcoded hex literal.
///
/// `MutedOnSurface` vs `Surface` is already covered by
/// `PlacesListContrastTests.mutedOnSurfaceMeetsAA` — not duplicated here.
/// **Deliberately not asserted, per §4.12:** the native `Slider`'s thumb
/// and inactive rail — both platform-drawn, outside this app's authored
/// contrast surface, and asserting them would fail against the very
/// control the PRD requires (D5).
@Suite("Heat modal / edge-hour contrast (§4.12)")
struct HeatModalContrastTests {
    @Test("MutedOnSurface meets WCAG AA 4.5:1 against PillSurface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func mutedOnSurfaceMeetsAAAgainstPillSurface(style: UIUserInterfaceStyle) throws {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let muted = try #require(UIColor(named: "MutedOnSurface", in: .main, compatibleWith: trait))
        let pillSurface = try #require(UIColor(named: "PillSurface", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(muted.resolvedColor(with: trait), pillSurface.resolvedColor(with: trait))
        #expect(ratio >= 4.5, "\(style) MutedOnSurface-on-PillSurface contrast was \(ratio), below WCAG AA 4.5:1")
    }

    @Test("NowTick meets the 3:1 non-text minimum against Surface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func nowTickMeetsNonTextMinimum(style: UIUserInterfaceStyle) throws {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let nowTick = try #require(UIColor(named: "NowTick", in: .main, compatibleWith: trait))
        let surface = try #require(UIColor(named: "Surface", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(nowTick.resolvedColor(with: trait), surface.resolvedColor(with: trait))
        #expect(ratio >= 3.0, "\(style) NowTick-on-Surface contrast was \(ratio), below the 3:1 non-text minimum")
    }

    @Test("SliderFill meets the 3:1 non-text minimum against Surface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func sliderFillMeetsNonTextMinimum(style: UIUserInterfaceStyle) throws {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let sliderFill = try #require(UIColor(named: "SliderFill", in: .main, compatibleWith: trait))
        let surface = try #require(UIColor(named: "Surface", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(sliderFill.resolvedColor(with: trait), surface.resolvedColor(with: trait))
        #expect(ratio >= 3.0, "\(style) SliderFill-on-Surface contrast was \(ratio), below the 3:1 non-text minimum")
    }

    @Test("EdgeRail meets the 3:1 non-text minimum against Surface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func edgeRailMeetsNonTextMinimum(style: UIUserInterfaceStyle) throws {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let edgeRail = try #require(UIColor(named: "EdgeRail", in: .main, compatibleWith: trait))
        let surface = try #require(UIColor(named: "Surface", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(edgeRail.resolvedColor(with: trait), surface.resolvedColor(with: trait))
        #expect(ratio >= 3.0, "\(style) EdgeRail-on-Surface contrast was \(ratio), below the 3:1 non-text minimum")
    }
}
