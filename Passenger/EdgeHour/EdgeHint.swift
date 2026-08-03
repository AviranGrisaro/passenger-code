import SwiftUI

/// The idle affordance for a live edge (TRD §4.11, Q8). Q8 is ratified:
/// deliberately persistent chrome, an explicit exception to the PRD's "not
/// permanent chrome" line — build it as specced, not as an unresolved
/// tension.
///
/// Opaque `Surface`, never translucent over a live map, for the same reason
/// T-031 §8 D1 gave: a ratio against unknown map pixels is not a number
/// anyone can verify. `.allowsHitTesting(false)` — the 24pt `EdgeHourZone`
/// owns every touch; this is purely visual.
struct EdgeHint: View {
    let edge: HorizontalEdge
    let band: ClosedRange<CGFloat>

    var body: some View {
        Capsule()
            .fill(Color("Surface"))
            .frame(width: EdgeGeometry.hintSize.width, height: EdgeGeometry.hintSize.height)
            .overlay(
                // The 1pt inner mark (§4.11) — a short vertical hairline,
                // not a full stroke outline.
                Rectangle()
                    .fill(Color("MutedOnSurface"))
                    .frame(width: 1, height: EdgeGeometry.hintSize.height * 0.4)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)  // §4.11: supplementary raw-pixel gesture, not narrated
    }
}

/// iPad's right edge (TRD §4.11): a faint neutral ghost mark instead of a
/// hint, so the absence reads as "OS-reserved" (Slide Over) rather than as
/// a missed build (design §3).
struct EdgeHintGhostMark: View {
    var body: some View {
        Rectangle()
            .fill(Color("MutedOnSurface").opacity(0.15))
            .frame(width: 2, height: EdgeGeometry.hintSize.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
