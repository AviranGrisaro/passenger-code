import Testing
import UIKit
@testable import Passenger

/// T-034 TRD §4.5, §9 row 2b: `Color("EventMarker")` must be distinct from
/// every `HeatBand` fill and clear WCAG 3:1 against each, in both
/// `UIUserInterfaceStyle`s. Resolves the *actual* Asset Catalog colour set
/// under real light/dark traits, same discipline `ContrastRatioTests`'
/// `SettingsHintContrastTests` established for `LinkOnSurface`/`Surface` —
/// a hardcoded-hex duplicate of the current values would verify the math
/// once and then drift silently the next time the colour changes.
///
/// A separate file rather than an addition to `ContrastRatioTests.swift`
/// purely to avoid touching a file another concurrent session in this
/// working tree is actively editing.
@Suite("EventLayer contrast (T-034 TRD §4.5, §9 row 2b)")
struct EventLayerContrastTests {
    @Test("EventMarker clears 3:1 against every HeatBand fill, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func eventMarkerClearsContrastAgainstEveryBand(style: UIUserInterfaceStyle) throws {
        // Unit tests run inside the host app process (`TEST_HOST`), so
        // `Bundle.main` is the compiled app bundle with the real asset
        // catalog, not the test bundle's own.
        let trait = UITraitCollection(userInterfaceStyle: style)
        let marker = try #require(UIColor(named: "EventMarker", in: .main, compatibleWith: trait))
        let resolvedMarker = marker.resolvedColor(with: trait)

        for band in HeatBand.allCases {
            // `HeatPalette.fill(for:)` only varies alpha, never RGB, so this
            // is checked once per band for §9's own stated coverage even
            // though `ContrastRatio` (correctly, per WCAG) reads RGB only.
            let fill = UIColor(HeatPalette.fill(for: band))
            let resolvedFill = fill.resolvedColor(with: trait)
            let ratio = ContrastRatio.ratio(resolvedMarker, resolvedFill)
            #expect(ratio >= 3.0, "\(style) EventMarker vs \(band) was \(ratio), below the required 3:1")
        }
    }

    @Test("EventMarker itself differs across light and dark appearance — not a single flat colour mistakenly shared")
    func eventMarkerVariesByAppearance() throws {
        let lightTrait = UITraitCollection(userInterfaceStyle: .light)
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)
        let light = try #require(UIColor(named: "EventMarker", in: .main, compatibleWith: lightTrait)).resolvedColor(with: lightTrait)
        let dark = try #require(UIColor(named: "EventMarker", in: .main, compatibleWith: darkTrait)).resolvedColor(with: darkTrait)

        var lightRGBA = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), a: CGFloat(0))
        var darkRGBA = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), a: CGFloat(0))
        light.getRed(&lightRGBA.r, green: &lightRGBA.g, blue: &lightRGBA.b, alpha: &lightRGBA.a)
        dark.getRed(&darkRGBA.r, green: &darkRGBA.g, blue: &darkRGBA.b, alpha: &darkRGBA.a)

        #expect(lightRGBA.r != darkRGBA.r || lightRGBA.g != darkRGBA.g || lightRGBA.b != darkRGBA.b)
    }
}
