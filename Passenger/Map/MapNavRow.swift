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
struct MapNavRow: View {
    let isHeatPresented: Bool
    let onHeatTap: () -> Void
    let isSearchPresented: Bool
    let onSearchTap: () -> Void
    let isPassportPresented: Bool
    let onProfileTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            HeatButton(isPresented: isHeatPresented, action: onHeatTap)
            SearchButton(isPresented: isSearchPresented, action: onSearchTap)
            ProfileButton(isPresented: isPassportPresented, action: onProfileTap)
        }
    }
}
