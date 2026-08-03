import SwiftUI

/// The always-visible nav row (T-032 D1/D6, TRD §2.3 z7): "separate
/// side-by-side buttons, no shared container chrome" — so a later button
/// (T-032's heat toggle, a future Passport entry point) can join this row
/// without this task inventing shared chrome for it to sit inside. Carries
/// only the search button today (search-quick-filters TRD §11 C6); the row
/// itself adds no background, no border, nothing that groups buttons that
/// don't belong together.
///
/// Always visible, always hit-testable, never covered by this file's own
/// z3/z5 additions elsewhere in `MapScreen` — it is the reason D1 there is
/// what it is (TRD §2.3).
struct MapNavRow: View {
    let isSearchPresented: Bool
    let onSearchTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            SearchButton(isPresented: isSearchPresented, action: onSearchTap)
        }
    }
}
