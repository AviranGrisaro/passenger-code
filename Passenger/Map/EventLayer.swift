import MapKit
import SwiftUI

/// One live-event marker (TRD §4.5, D2, D5, D7). Built as a near-copy of the
/// shipped `PlaceLayer`: an `Annotation` holding a real `Button` (VoiceOver
/// needs an activatable element), reporting a tap by calling `action`
/// directly — the same idempotent two-path pattern `PlaceLayer` already
/// ships, since `MapScreen`'s own `SpatialTapGesture` can fire for the same
/// physical tap via `EventHitTester`, and `DetailRouter.openEvent` is
/// idempotent, so both paths landing is safe.
///
/// Emits `Annotation` only — no `MapPolygon`, no area `foregroundStyle` — so
/// this layer structurally cannot compete with heat's area channel (§2.3,
/// req 2 bullet 1). Not built here: clustering (`T-041`, unowned, §8 D4).
///
/// **T-062/PAS-58, post-ship redesign pass (2026-08-04):** the visible glyph
/// was replaced — see `LiveEventMarkerGlyph` below for the design rationale.
/// The `Annotation`/`Button`/accessibility structure here is otherwise
/// untouched; this pass only changed what's drawn inside the 44×44 frame.
struct EventLayer: MapContent {
    let event: LiveEvent
    let action: () -> Void

    var body: some MapContent {
        Annotation(event.name, coordinate: event.coordinate) {
            Button(action: action) {
                LiveEventMarkerGlyph()
                    .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2) — tap target unchanged; only the drawn content inside it shrank (T-062/PAS-58)
            }
            .accessibilityLabel("\(event.name), event, \(event.timeLabel)")
            // Stable, locale-independent hook for UI tests, same reason
            // `PlaceLayer`'s `placePin-` identifier exists — events render at
            // every zoom (D2), so this is reachable directly, with no
            // zoomed-in launch argument needed the way place-pin UI tests do.
            .accessibilityIdentifier("eventMarker-\(event.id)")
        }
        .annotationTitles(.hidden)
    }
}

/// The glyph drawn inside `EventLayer`'s 44×44 tap target (T-062/PAS-58,
/// post-ship redesign — replaces the original 44×44 filled rounded-rect +
/// `sparkles` glyph, which this file's own comment flagged as
/// `[ASSUMPTION] §8 D5 — overturned in a line at the post-ship designer
/// pass`).
///
/// Founder feedback, verbatim (2026-08-04 live chat, recorded at
/// `PROGRESS.md`'s L-002 stub and `BOARD.md` T-062): "the icon of the live
/// events is too big. we need something more solid and small with micro
/// animation that will let the user know that there is a live event." Three
/// changes, not one:
///
/// - **Smaller.** The drawn shape shrinks from filling the full 44×44 frame
///   to an 18×18 core — the 44×44 *tap target* is untouched (Fitts's Law,
///   `design-principles.md` §2, req 4 above); only what's visible inside it
///   got smaller.
/// - **More solid.** A fully filled rounded square, no thin glyph floating
///   on top — the old `sparkles` SF Symbol read as airy/thin at any size,
///   and more so once shrunk. Kept the rounded-square silhouette rather than
///   `PlaceLayer`'s `Circle`: the *shape*, not the icon, is what survives
///   greyscale and separates an event pin from a place pin
///   (`design-principles.md` §3, "never rely on color alone") — that
///   reasoning didn't depend on the icon and still holds with it removed.
///   **P1 considered, not applied:** a diamond/star silhouette instead of a
///   rounded square. Rejected — at 18pt map scale a diamond reads close
///   enough to a small circle to blur the exact place/event distinction
///   this shape exists for, while the rounded square stays unambiguous at
///   this size and the smaller diff is free.
/// - **Micro-animation.** A soft halo pulses outward from the solid core and
///   fades, looping. Capped at 30×30 — well inside the marker's own
///   footprint — so it can't compete with the heatmap's own area/fill
///   channel (this file's §2.3 req 2 bullet 1 guarantee, unchanged).
///   Disabled outright under Reduce Motion (`design-principles.md` §3,
///   "Respect `prefers-reduced-motion`"): the halo view isn't even built,
///   and the core renders solid and static — no substitute motion, no
///   flicker.
private struct LiveEventMarkerGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private let coreSize: CGFloat = 18
    private let haloSize: CGFloat = 30

    var body: some View {
        ZStack {
            if !reduceMotion {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color("EventMarker"))
                    .frame(width: haloSize, height: haloSize)
                    .opacity(isPulsing ? 0 : 0.45)
                    .scaleEffect(isPulsing ? 1 : 0.6)
            }
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color("EventMarker"))
                .frame(width: coreSize, height: coreSize)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
