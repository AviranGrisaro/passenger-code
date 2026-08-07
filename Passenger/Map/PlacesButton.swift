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
            // T-078/`PAS-60` reopened (`nav-row-v2-redesign.md` §3):
            // `list.bullet` → `bookmark.fill`, matching `PlaceDetailModal`'s
            // own per-place save button (`isSaved ? "bookmark.fill" :
            // "bookmark"`) exactly — closes a same-app two-glyphs-for-one-
            // concept inconsistency (this button had no glyph collision with
            // that one, `list.bullet` just wasn't the save/bookmark
            // convention). No "saved" binary state of its own (it's a
            // static entry point, not a toggle), so it's the filled variant
            // permanently, reading as "your bookmarks" (Safari Reading
            // List/Apple News/Apple Maps' own Saved Places convention).
            Image(systemName: "bookmark.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.teal)  // §4 — analogous blue/indigo/teal family
                .frame(width: 52, height: 52)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Places")
    }
}
