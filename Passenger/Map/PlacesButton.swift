import SwiftUI

/// The entry point to the Places list — a nav-row button (PAS-42,
/// 2026-08-04: merged into `MapNavRow`, correcting T-036's own D7, which had
/// corrected T-032's D1 the other way). Built to the existing
/// `NearMeButton`/`HoodButton` chrome idiom: same 44×44 target, same
/// `.thinMaterial` circle.
///
/// **No longer fades.** D7 originally faded this button to invisible
/// whenever any `NavSurface` was presented, specifically so it couldn't be
/// re-tapped to dismiss its own open list. PAS-42 merged it into the
/// always-visible nav row instead (D1 wins for the row — see `MapNavRow`'s
/// header comment for why), so that protection now lives as a guard in
/// `MapScreen.openPlacesList` (a no-op while `.places` is already
/// presented) rather than in this view's visibility. The three other
/// dismissal paths D7 named (✕, drag-past-threshold, tap-outside-scrim) are
/// unchanged.
struct PlacesButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // [ASSUMPTION] Icon deferred by the design spec (§8 D7's
            // reference row names no exact symbol) — `list.bullet` reads as
            // "your places list" without colliding with the per-place save
            // glyph (`bookmark`/`bookmark.fill`, `PlaceDetailModal`) or the
            // nearest-Hood glyph (`mappin.and.ellipse`, `HoodButton`).
            Image(systemName: "list.bullet")
                .font(.title3)
                .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Places")
    }
}
