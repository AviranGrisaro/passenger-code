import SwiftUI

/// The single band → opacity table (TRD §4.1, PRD req 4). One hue, stepped by
/// opacity only, never by hue and never by a computed gradient.
///
/// `opacity(for:)` takes exactly one argument. Any future signature that adds a
/// zoom, camera, or altitude term is a PRD req-4 violation — `ios-code-reviewer`
/// should treat an added parameter as a blocking finding, per the TRD's own note.
enum HeatPalette {
    /// One hue, light/dark asset variants (`Assets.xcassets/HeatFill.colorset`,
    /// values from `design/mockup-prompts.md`: light `#E24E1F`, dark `#FF7A4D`).
    static var hue: Color { Color("HeatFill") }

    /// Illustrative defaults from the approved mockup (TRD §4.1). Real thresholds
    /// are `data-engineer`'s call (B1) — the client never computes one, it only
    /// maps an already-decided band to an opacity step.
    static func opacity(for band: HeatBand) -> Double {
        switch band {
        case .quiet: 0.16
        case .moderate: 0.38
        case .busy: 0.62
        }
    }

    /// `nil` band → no fill at all (PRD req 7) — the caller applies `.clear`,
    /// not this enum, since "no data" isn't a color decision.
    static func fill(for band: HeatBand) -> Color {
        hue.opacity(opacity(for: band))
    }

    /// The fill's own dim factor (search-quick-filters TRD §4.10), folded in
    /// here as a pure numeric composition rather than left to `HoodLayer` to
    /// apply as a view modifier — so "does a layer's dim reach its heat
    /// fill" is a unit-testable question about two `Double`s, not a fact
    /// about a SwiftUI modifier chain no test can observe. This is an
    /// *additional* function, not a change to `opacity(for:)`'s signature —
    /// that one still takes exactly one argument, per this file's own rule
    /// above.
    ///
    /// Added at T-038/PAS-29's second acceptance pass (F1a): `HoodLayer`
    /// applied its dim multiplier to the polygon's stroke and to the
    /// centroid annotation, but never to `foregroundStyle(fillColor)` —
    /// despite `HoodLayer`'s own doc comments twice claiming the dim
    /// "multiplies every visible element's opacity." A non-matching Hood
    /// kept its full-strength heat fill during an active search, which is
    /// the channel PRD req 4 bullet 2 is actually about (the fill dominates
    /// a 0.5pt stroke). `dimOpacity` of `1` is a no-op, so every caller that
    /// predates search's dim renders byte-identically to before.
    static func fillOpacity(for band: HeatBand, dimmedBy dimOpacity: Double) -> Double {
        opacity(for: band) * dimOpacity
    }
}
