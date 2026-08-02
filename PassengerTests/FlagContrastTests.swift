import Testing
import UIKit
@testable import Passenger

/// tourist-trap-flag TRD §11 C4: resolves the *actual* `Flag.colorset`
/// asset, under real light/dark `UITraitCollection`s — same discipline
/// `SettingsHintContrastTests` established, so a designer edit to the
/// asset can't silently drift the computed ratios out of spec without a
/// test noticing.
@Suite("Flag contrast (§11 C4)")
struct FlagContrastTests {
    @Test("Flag meets WCAG AA 4.5:1 text contrast against Surface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func flagMeetsTextContrastAgainstSurface(style: UIUserInterfaceStyle) throws {
        // Unit tests here run inside the host app process (`TEST_HOST`), so
        // `Bundle.main` is the compiled app bundle with the real asset
        // catalog — not the test bundle's own.
        let trait = UITraitCollection(userInterfaceStyle: style)

        let flag = try #require(UIColor(named: "Flag", in: .main, compatibleWith: trait))
        let surface = try #require(UIColor(named: "Surface", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(flag.resolvedColor(with: trait), surface.resolvedColor(with: trait))
        #expect(ratio >= 4.5, "\(style) Flag-on-Surface contrast was \(ratio), below WCAG AA 4.5:1")
    }

    @Test("Flag meets WCAG AA 4.5:1 text contrast against the system background, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func flagMeetsTextContrastAgainstBackground(style: UIUserInterfaceStyle) throws {
        // No dedicated "Background" asset exists in this app (the map's own
        // background is MapKit tile imagery, not a solid color) — `--bg` in
        // the design reference's own contrast figures is a generic app
        // background, which `.systemBackground` is the platform's own
        // dynamic-color equivalent of.
        let trait = UITraitCollection(userInterfaceStyle: style)
        let flag = try #require(UIColor(named: "Flag", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(flag.resolvedColor(with: trait), UIColor.systemBackground.resolvedColor(with: trait))
        #expect(ratio >= 4.5, "\(style) Flag-on-background contrast was \(ratio), below WCAG AA 4.5:1")
    }

    @Test("Flag meets the 3:1 non-text graphical-element minimum against Surface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func flagMeetsStrokeContrastAgainstSurface(style: UIUserInterfaceStyle) throws {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let flag = try #require(UIColor(named: "Flag", in: .main, compatibleWith: trait))
        let surface = try #require(UIColor(named: "Surface", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(flag.resolvedColor(with: trait), surface.resolvedColor(with: trait))
        #expect(ratio >= 3.0, "\(style) Flag stroke-on-Surface contrast was \(ratio), below the 3:1 non-text minimum")
    }
}
