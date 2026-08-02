import SwiftUI

/// The entry point to the Places list — bucket-2 chrome, **not** a nav-row
/// button (TRD §2.4, D7, corrects T-032's own D1). Built to the existing
/// `NearMeButton`/`HoodButton` chrome idiom: same bottom band, same
/// materials. Joins that cluster and fades with it: while any `NavSurface`
/// is presented this button fades to invisible and stops accepting taps, so
/// it cannot be re-tapped to dismiss its own open list (the accepted cost
/// named at D7 — three other dismissal paths exist on the list itself).
struct PlacesButton: View {
    let isFaded: Bool
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
        .opacity(isFaded ? 0 : 1)
        .allowsHitTesting(!isFaded)
    }
}
