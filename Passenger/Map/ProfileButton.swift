import SwiftUI

/// The 3rd nav-row button (passport TRD §2.4, D9) — `ux-flows.md` §2 names
/// Profile "the 3rd of the 3 side-by-side nav buttons," so unlike Places
/// (T-036's D7 correction) this sits exactly where T-032's D1 anticipated:
/// z7, icon-only, no caption (`ux-flows.md`'s 2026-08-02 founder-direct
/// addendum, T-032's D6 states the same rule for the heat button).
///
/// **Not wired into `MapNavRow` here.** `MapNavRow.swift` does not exist yet
/// — T-032's own C2 has not landed in this working tree — and TRD §11 C7
/// blocks on that step and explicitly forbids creating the container file
/// from this task. This view is built to the contract C2's container will
/// host it in; landing C2 adds one call site to `MapNavRow`'s row of
/// buttons, not a new component.
struct ProfileButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // [ASSUMPTION] D9 — the conventional profile-tab glyph. A
            // static system symbol, never user-supplied imagery, and must
            // never become one — req 1's avatar ban is enforced by §9 row
            // 1's grep, not by this choice.
            Image(systemName: "person.fill")
                .font(.title3)
                .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2)
        }
        .accessibilityLabel("Profile")
    }
}
