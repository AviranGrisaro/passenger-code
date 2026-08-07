import SwiftUI

/// The entry point to search (TRD §11 C6) — icon-only, no caption
/// (`ux-flows.md` 2026-08-02 founder-direct addendum), built to the existing
/// `NearMeButton`/`HoodButton` floating-chrome idiom: same 44×44 target, same
/// `.thinMaterial` circle. Lives in `MapNavRow` (z7), not bucket-2 chrome —
/// it must stay reachable while a `NavSurface` is presented, which is
/// exactly what distinguishes the nav row from bucket-2 (T-032 D1).
///
/// **T-078/`PAS-60` reopened:** this button now also opens the map-hour
/// slider — folded into `SearchOverlay` as its "Hour" segment
/// (`nav-row-v2-redesign.md` §1). The old standalone `HeatButton` is
/// deleted; `chrome.presented == .search` covers both segments.
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
        // "Search and hours", not "Search" (`PAS-75`, ridden along with
        // T-079/`PAS-73`): since T-078/`PAS-60` folded the old `HeatButton`
        // into `SearchOverlay`'s own "Search"/"Hour" segmented control, this
        // button's own VoiceOver label collided with that control's
        // "Search" segment label — both audible in the same screen once the
        // overlay is open, since `MapNavRow` stays hit-testable underneath
        // it by design. No visible change (the glyph is unchanged); this
        // also happens to describe what the button now actually opens more
        // accurately than "Search" alone did.
        .accessibilityLabel("Search and hours")
        .accessibilityAddTraits(isPresented ? [.isSelected] : [])
    }
}
