import SwiftUI

/// The entry point to search (TRD §11 C6) — icon-only, no caption
/// (`ux-flows.md` 2026-08-02 founder-direct addendum), built to the existing
/// `NearMeButton`/`HoodButton` floating-chrome idiom: same 44×44 target, same
/// `.thinMaterial` circle. Lives in `MapNavRow` (z7), not bucket-2 chrome —
/// it must stay reachable while a `NavSurface` is presented, which is
/// exactly what distinguishes the nav row from bucket-2 (T-032 D1).
///
/// **T-078/`PAS-60` reopened:** this button used to also open the map-hour
/// slider, folded into `SearchOverlay` as its "Hour" segment
/// (`nav-row-v2-redesign.md` §1) — the old standalone `HeatButton` stayed
/// deleted. **T-081/`PAS-76`:** the Hour segment itself is now gone too
/// (`EdgeHourZone`/`EdgeHourTrack`, "the sides", already cover hour
/// selection), so this button is back to opening Search alone.
struct SearchButton: View {
    let isPresented: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.blue)  // T-078/`PAS-60` reopened §4 — analogous blue/indigo/teal family, ring dropped
                .frame(width: 52, height: 52)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
        }
        // Reverted to plain "Search" at T-081/`PAS-76`. `PAS-75` had
        // renamed this to "Search and hours" because `SearchOverlay`'s own
        // Search/Hour segmented control rendered a same-labeled "Search"
        // segment button once the overlay was open — both audible in the
        // same screen, since `MapNavRow` stays hit-testable underneath it
        // by design. That segmented control is deleted along with the Hour
        // segment, so there is no more colliding label to disambiguate.
        .accessibilityLabel("Search")
        .accessibilityAddTraits(isPresented ? [.isSelected] : [])
    }
}
