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
                .font(.title3)
                .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Heat")
        .accessibilityAddTraits(isPresented ? [.isSelected] : [])
    }
}
