import SwiftUI

/// The always-visible nav row (T-032 D1/D6, TRD §2.3 z7): "separate
/// side-by-side buttons, no shared container chrome" — so the search button
/// (search-quick-filters TRD §11 C6) and the profile/Passport button
/// (passport TRD §11 C7) sit here with no re-layout and no shared
/// background, border, or grouping added.
///
/// Always visible, always hit-testable, never covered by this file's own
/// z3/z5 additions elsewhere in `MapScreen` — it is the reason D1 there is
/// what it is (TRD §2.3).
///
/// **PAS-42 (2026-08-04, founder-direct): 5 icon buttons lived here.**
/// `NearMeButton` and `PlacesButton` moved in from a second, lower
/// "bucket-2 chrome" row so all 5 buttons shared one show/hide rule (D1's
/// "always visible, always hit-testable, never covered," not D7's fade).
///
/// **T-078/`PAS-60` reopened (`nav-row-v2-redesign.md`): back down to 3.**
/// `HeatButton` is deleted — its function folded into `SearchButton`'s own
/// surface as an in-overlay "Hour" segment (`SearchOverlay.swift` §1), so
/// there is no longer a 4th button for it. `NearMeButton` relocated again,
/// this time out of this row entirely into `MapScreen`'s top-trailing
/// overlay (Apple/Google-Maps-style placement, §2) — it keeps the same
/// always-visible behavior it had here, just at a new home. `PlacesButton`
/// stays, with its PAS-42 no-fade/no-`isFaded`-parameter behavior and its
/// `MapScreen.openPlacesList` re-tap guard both unchanged by this pass.
struct MapNavRow: View {
    let isSearchPresented: Bool
    let onSearchTap: () -> Void
    let isPassportPresented: Bool
    let onProfileTap: () -> Void
    let onPlacesTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            SearchButton(isPresented: isSearchPresented, action: onSearchTap)
            ProfileButton(isPresented: isPassportPresented, action: onProfileTap)
            PlacesButton(action: onPlacesTap)
        }
        // TRD §9 row 5b's own build note: this row's frame, as a whole,
        // needs to be queryable from a UI test. The individual buttons
        // already carry their own labels ("Search"/"Profile"/"Places") for
        // regression tests; this is the container's own identity, not a
        // replacement for those.
        .accessibilityIdentifier("mapNavRow")
        .accessibilityElement(children: .contain)
    }
}
