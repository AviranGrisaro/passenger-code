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
}
