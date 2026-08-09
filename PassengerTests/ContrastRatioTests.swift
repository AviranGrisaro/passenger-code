import Testing
import UIKit
@testable import Passenger

@Suite("ContrastRatio")
struct ContrastRatioTests {
    @Test("black on white is the maximum WCAG ratio, 21:1")
    func blackOnWhiteIsMaximum() {
        let ratio = ContrastRatio.ratio(.black, .white)
        #expect(abs(ratio - 21.0) < 0.01)
    }

    @Test("a color against itself is always 1:1")
    func sameColorIsMinimum() {
        #expect(abs(ContrastRatio.ratio(.systemBlue, .systemBlue) - 1.0) < 0.001)
    }

    @Test("argument order doesn't matter")
    func orderIndependent() {
        let a = ContrastRatio.ratio(.black, .white)
        let b = ContrastRatio.ratio(.white, .black)
        #expect(abs(a - b) < 0.0001)
    }
}

/// TRD §8 D1: resolves the *actual* Asset Catalog color sets, under real
/// light/dark `UITraitCollection`s, rather than duplicating today's computed
/// hex values as literals in the test file. A hardcoded-hex test verifies the
/// math once and then drifts silently the next time a designer edits either
/// color in the catalog — the exact failure mode both `ios-developer` and
/// `ios-code-reviewer` named at trd-review as having already happened twice.
@Suite("SettingsHint contrast (§8 D1)")
struct SettingsHintContrastTests {
    @Test("LinkOnSurface meets WCAG AA 4.5:1 against Surface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func linkContrastMeetsAA(style: UIUserInterfaceStyle) throws {
        // Unit tests here run inside the host app process (`TEST_HOST`), so
        // `Bundle.main` is the compiled app bundle with the real asset
        // catalog — not the test bundle's own.
        let trait = UITraitCollection(userInterfaceStyle: style)

        let link = try #require(UIColor(named: "LinkOnSurface", in: .main, compatibleWith: trait))
        let surface = try #require(UIColor(named: "Surface", in: .main, compatibleWith: trait))

        let resolvedLink = link.resolvedColor(with: trait)
        let resolvedSurface = surface.resolvedColor(with: trait)

        let ratio = ContrastRatio.ratio(resolvedLink, resolvedSurface)
        #expect(ratio >= 4.5, "\(style) contrast was \(ratio), below WCAG AA 4.5:1")
    }
}

/// places-been-saved TRD §4.10, §9 row 4d — same construction as
/// `SettingsHintContrastTests`: resolves the real Asset Catalog color sets
/// under real light/dark trait collections rather than duplicating hex
/// literals, so this stays correct if a designer edits the catalog later.
///
/// **Known blind spot, accepted deliberately (T-106/`PAS-106`, 2026-08-09):**
/// `PlacesListOverlay`'s card background is now `.glassEffect()`
/// (`ModalGlassBackground`, `Support/ModalGlassBackground.swift`), not the
/// opaque `Color("Surface")` this suite was written against at `PAS-27`.
/// `mutedOnSurfaceMeetsAA`/`badgeTokensMeetAA` below still pass — but they
/// only ever measured the *static* `MutedOnSurface`/`BadgeOnSurface` vs.
/// `Surface`/`BadgeSurface` color-pair math, which was already true before
/// this change and stays true after it; they say nothing about the actual
/// on-screen contrast once that card is composited over the live map, which
/// is the case this reversal reintroduces. There is no unit-testable
/// equivalent — see `design-principles.md` §8a for the human-eyeball-check
/// process this now requires instead.
@Suite("Places list contrast (§4.10)")
struct PlacesListContrastTests {
    @Test("MutedOnSurface meets WCAG AA 4.5:1 against Surface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func mutedOnSurfaceMeetsAA(style: UIUserInterfaceStyle) throws {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let muted = try #require(UIColor(named: "MutedOnSurface", in: .main, compatibleWith: trait))
        let surface = try #require(UIColor(named: "Surface", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(muted.resolvedColor(with: trait), surface.resolvedColor(with: trait))
        #expect(ratio >= 4.5, "\(style) contrast was \(ratio), below WCAG AA 4.5:1")
    }

    @Test("BadgeOnSurface meets WCAG AA 4.5:1 against BadgeSurface, light and dark", arguments: [
        UIUserInterfaceStyle.light,
        UIUserInterfaceStyle.dark,
    ])
    func badgeTokensMeetAA(style: UIUserInterfaceStyle) throws {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let onSurface = try #require(UIColor(named: "BadgeOnSurface", in: .main, compatibleWith: trait))
        let surface = try #require(UIColor(named: "BadgeSurface", in: .main, compatibleWith: trait))

        let ratio = ContrastRatio.ratio(onSurface.resolvedColor(with: trait), surface.resolvedColor(with: trait))
        #expect(ratio >= 4.5, "\(style) contrast was \(ratio), below WCAG AA 4.5:1")
    }
}
