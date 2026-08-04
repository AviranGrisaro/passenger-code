import SwiftUI

/// The entry point to search (TRD §11 C6) — icon-only, no caption
/// (`ux-flows.md` 2026-08-02 founder-direct addendum), built to the existing
/// `NearMeButton`/`HoodButton` floating-chrome idiom: same 44×44 target, same
/// `.thinMaterial` circle. Lives in `MapNavRow` (z7), not bucket-2 chrome —
/// it must stay reachable while a `NavSurface` is presented, which is
/// exactly what distinguishes the nav row from bucket-2 (T-032 D1).
struct SearchButton: View {
    let isPresented: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.blue)
                .frame(width: 52, height: 52)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.blue.opacity(0.9), lineWidth: 1.5))
        }
        .accessibilityLabel("Search")
        .accessibilityAddTraits(isPresented ? [.isSelected] : [])
    }
}
