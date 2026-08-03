import SwiftUI

/// Pure edge-zone geometry (TRD §4.9, §8 D8). No map, no density, no
/// gesture — a touch position in, an hour out, testable with no simulator.
///
/// The design's 64pt/40pt figures are confirmed correct for the reference
/// device (top: 59pt Dynamic-Island safe area + 5pt clearance; bottom: 34pt
/// home-indicator safe area + 6pt clearance) and re-derived as
/// `max(floor, safeAreaInset + clearance)` so they hold on every device
/// instead of only that one.
enum EdgeGeometry {
    /// Q7, ratified 2026-08-02 — the acquisition argument, not the
    /// (corrected, §2.4/D7) arbitration one.
    static let captureWidth: CGFloat = 24
    static let topFloor: CGFloat = 64
    static let bottomFloor: CGFloat = 40
    static let hintSize = CGSize(width: 5, height: 56)

    /// The usable vertical band, in this view's own `.local` coordinates
    /// (§4.8) — computed fresh from the live `GeometryProxy` on every
    /// layout pass, never stored (§3.3).
    static func band(in size: CGSize, safeArea: EdgeInsets) -> ClosedRange<CGFloat> {
        let top = max(topFloor, safeArea.top + 5)
        let bottom = max(bottomFloor, safeArea.bottom + 6)
        // Degenerate-but-safe on a hypothetical device too short for both
        // floors to fit — never constructs an invalid `ClosedRange` (which
        // would trap), collapses to a single point instead.
        let bottomY = max(top, size.height - bottom)
        return top...bottomY
    }

    /// Absolute position, not delta — this is what makes "all 13 hours
    /// reachable wherever the finger first lands" true by construction. Up
    /// is later. Clamped to `0...12`.
    static func hour(atY y: CGFloat, in band: ClosedRange<CGFloat>) -> Int {
        let length = band.upperBound - band.lowerBound
        guard length > 0 else { return 0 }
        let raw = (band.upperBound - y) / length * 12
        let rounded = Int(raw.rounded())
        return min(12, max(0, rounded))
    }

    /// The inverse of `hour(atY:in:)`, used to position the readout chip and
    /// (P1) the track's drawn stops. Clamped the same way, so the chip stays
    /// pinned at the end of the band rather than floating past it.
    static func y(forHour hour: Int, in band: ClosedRange<CGFloat>) -> CGFloat {
        let clampedHour = min(12, max(0, hour))
        let length = band.upperBound - band.lowerBound
        return band.upperBound - (CGFloat(clampedHour) / 12) * length
    }
}
