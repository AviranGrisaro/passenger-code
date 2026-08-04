import SwiftUI

/// The nav row's heat button (TRD §2.3, D1/D6) — opens `HeatModalCard`.
/// Icon-only, no caption (`ux-flows.md` 2026-08-02 founder-direct
/// addendum), built to the same `SearchButton`/`HoodButton` chrome idiom:
/// 44×44 target, `.thinMaterial` circle. Glyph `flame.fill`, pinned by
/// `designer` 2026-08-02 — `NearMeButton`'s `location.fill` is the
/// established default-to-`.fill` precedent for a circular chrome button,
/// and "modal open" is already carried by the button's own background so a
/// glyph swap would be a redundant second channel.
struct HeatButton: View {
    let isPresented: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "flame.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.orange)
                .frame(width: 52, height: 52)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.orange.opacity(0.9), lineWidth: 1.5))
        }
        .accessibilityLabel("Heat")
        .accessibilityAddTraits(isPresented ? [.isSelected] : [])
    }
}
