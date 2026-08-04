import SwiftUI

/// The 3rd nav-row button (passport TRD §2.4, D9) — `ux-flows.md` §2 names
/// Profile "the 3rd of the 3 side-by-side nav buttons," so unlike Places
/// (T-036's D7 correction) this sits exactly where T-032's D1 anticipated:
/// z7, icon-only, no caption (`ux-flows.md`'s 2026-08-02 founder-direct
/// addendum, T-032's D6 states the same rule for the heat button).
///
/// **Wired into `MapNavRow`** — landed once `MapNavRow.swift` existed
/// (T-038's build) and settled, per this file's own original comment
/// ("landing C2 adds one call site... not a new component") and TRD §11
/// C7. `isPresented` mirrors `SearchButton`'s own parameter: same
/// `.isSelected` accessibility signal while its surface is open, no visual
/// difference beyond that (D10 — nothing in Passport is tappable, so there
/// is no "active" look to design beyond VoiceOver state).
struct ProfileButton: View {
    let isPresented: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // [ASSUMPTION] D9 — the conventional profile-tab glyph. A
            // static system symbol, never user-supplied imagery, and must
            // never become one — req 1's avatar ban is enforced by §9 row
            // 1's grep, not by this choice.
            Image(systemName: "person.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.purple)
                .frame(width: 52, height: 52)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.purple.opacity(0.9), lineWidth: 1.5))
        }
        .accessibilityLabel("Profile")
        .accessibilityAddTraits(isPresented ? [.isSelected] : [])
    }
}
