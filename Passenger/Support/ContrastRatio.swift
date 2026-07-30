import UIKit

/// WCAG 2.x contrast-ratio calculator.
///
/// `SALVAGE.md` flags the original `Support/ContrastRatio.swift` (Locali) REUSE —
/// but this sandboxed build session cannot reach `../../locali/` on disk or
/// `github.com/AviranGrisaro/locali` over the network (same access gap
/// `data-engineer` hit for B2/B3 at `trd-review`, PROGRESS.md 2026-07-30).
/// Re-implemented fresh from the public WCAG 2.x relative-luminance formula
/// rather than blocking on salvage access — flagged here and in the build
/// report for whoever can reach the archive to diff against the original.
enum ContrastRatio {
    /// WCAG relative luminance, sRGB color space.
    private static func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linearize(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// WCAG contrast ratio between two colors. Always ≥1.0 — order of the two
    /// arguments doesn't matter, the lighter one is always treated as the numerator.
    static func ratio(_ first: UIColor, _ second: UIColor) -> Double {
        let l1 = relativeLuminance(first)
        let l2 = relativeLuminance(second)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
