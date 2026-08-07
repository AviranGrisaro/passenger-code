import CoreLocation
import SwiftUI

/// The always-visible nav row (T-032 D1/D6, TRD §2.3 z7): "separate
/// side-by-side buttons, no shared container chrome" — so the heat button
/// (T-032's own C2) joins the search button (search-quick-filters TRD §11
/// C6) and the profile/Passport button (passport TRD §11 C7) that landed
/// here first in the shared working tree, with no re-layout and no shared
/// background, border, or grouping added.
///
/// Always visible, always hit-testable, never covered by this file's own
/// z3/z5 additions elsewhere in `MapScreen` — it is the reason D1 there is
/// what it is (TRD §2.3).
///
/// **PAS-42 (2026-08-04, founder-direct): all 5 icon buttons now live here,
/// not just 3.** `NearMeButton` and `PlacesButton` moved in from a second,
/// lower "bucket-2 chrome" row (`MapScreen.swift`, formerly
/// `.padding(.bottom, 32)` vs. this row's `.padding(.bottom, 96)`) that D7
/// had them fading on any open `NavSurface`, while this row's own D1 never
/// faded. Two rows at two heights with two different show/hide rules is the
/// "two rows" the ticket describes and is also the original PAS-42 bug
/// (Passport's D7-scoped fade over-firing and clipping this row). Merging
/// them into one `HStack` forces one rule to win for all 5 buttons, and it
/// has to be **D1's "always visible, always hit-testable, never covered"**
/// — not D7's "fade so it can't re-open its own surface" — because D7
/// applied to the whole row would fade `HeatButton`/`ProfileButton` while
/// their *own* modal is open, breaking the already-shipped, already-tested
/// re-tap-to-close behavior (`HeatButtonInteractionTests
/// .testTappingHeatButtonAgainDismissesTheModal`,
/// `ProfileButtonInteractionTests.testTappingProfileButtonAgainDismissesPassport`).
/// `PlacesButton` loses its `isFaded` parameter as part of this merge — the
/// one thing D7 protected (Places can't be re-tapped to dismiss its own
/// list) is preserved instead as a guard in `MapScreen.openPlacesList`
/// (a no-op while `.places` is already presented), not by hiding the
/// button. `NearMeButton` and `HoodButton`/`SettingsHint`'s fade-with-any-
/// open-surface behavior is untouched by this change — `HoodButton`/
/// `SettingsHint` aren't icon buttons and stay out of this row entirely
/// (see `MapScreen.swift`'s remaining bottom overlay).
struct MapNavRow: View {
    let isHeatPresented: Bool
    let onHeatTap: () -> Void
    let isSearchPresented: Bool
    let onSearchTap: () -> Void
    let isPassportPresented: Bool
    let onProfileTap: () -> Void
    let nearMeAuthorizationStatus: CLAuthorizationStatus
    let onNearMeTap: () -> Void
    let onPlacesTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            HeatButton(isPresented: isHeatPresented, action: onHeatTap)
            SearchButton(isPresented: isSearchPresented, action: onSearchTap)
            ProfileButton(isPresented: isPassportPresented, action: onProfileTap)
            NearMeButton(authorizationStatus: nearMeAuthorizationStatus, action: onNearMeTap)
            PlacesButton(action: onPlacesTap)
        }
        // TRD §9 row 5b's own build note: this row's frame, as a whole,
        // needs to be queryable from a UI test — `HeatModalCard.frame`
        // vs. `MapNavRow.frame` is the whole of the row 5b (i) check. The
        // individual buttons already carry their own labels
        // ("Heat"/"Search"/"Profile"/etc.) for the F1 regression test; this
        // is the container's own identity, not a replacement for those.
        .accessibilityIdentifier("mapNavRow")
        .accessibilityElement(children: .contain)
    }
}
