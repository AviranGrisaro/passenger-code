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
///
/// **T-062/PAS-58, rejection-loop fix (2026-08-04):** `product`'s acceptance
/// pass measured this glyph at **0 px visible** at the seeded Florentin
/// event (`events-tel-aviv-seed.json` seed-0001, which sits exactly on
/// `florentin`'s Hood centroid) — `HoodLayer.swift`'s centroid name-pill
/// annotation (a `.thinMaterial` capsule, measured ~63×18pt for "Florentin")
/// draws above this glyph at that coordinate and, at 18×18, fully covers the
/// core. Root cause is compositing/overlap, not full annotation suppression
/// — a marker shifted clear of the label rendered at full size in the same
/// build, and `HoodLayer.swift`/`MapContent` declaration order was tested
/// and does not control which annotation wins the overlap (empirically,
/// reordering `hoodLayers` in `MapScreen.swift`'s `Map` builder made no
/// difference — not committed, not worth the added indirection for a lever
/// that doesn't move the outcome).
///
/// Fix, iteration 2 (a live-measured ring alone did not clear the bar — see
/// below): two small **legibility caps**, one above and one below the core,
/// each joined to it by a thin stem — product's fix option 2 ("give the
/// marker core an outline/stroke that extends past the label pill's
/// bounds"), reshaped once live measurement showed a ring's cost/benefit
/// was poor. Static (non-pulsing, always fully opaque), never gated on
/// `reduceMotion` — it's shape, not motion.
///
/// **Why not a ring (tried first, live-measured, reverted):** a `Hood`
/// centroid label's real rendered height, measured directly off a pixel
/// scan of the shipped "Florentin" capsule against this fix's own opaque
/// ring color (not inferred from a translucent-material bleed pattern the
/// way the first live measurement was) — **≈27pt, not the ≈18pt the first
/// pass estimated.** At the true height, a ring's *side* strokes are mostly
/// inside the label band no matter how tall the ring gets (a ring's side
/// bars scale with height but so does the fixed-height chunk of them that
/// stays covered), and the *core* is fully occluied ink with zero visible
/// return either way — together they capped two live-measured ring sizes
/// (40×40/6pt, then 50×50/10pt) at **35.8%** and **36.9%** visible, both
/// short of the PRD's half floor. Detaching the escaping ink from the
/// core — two caps, no side bars — removes exactly the two terms that were
/// capping the ratio.
///
/// **Geometry:** core 18×18 (unchanged — the "don't need to touch"
/// silhouette). Each cap is an 22×22 rounded square whose *center* sits
/// 30pt from the core's center — its near edge lands at 19pt, comfortably
/// past the measured ~27pt label's 13.5pt half-height, so each cap is
/// **entirely** outside the label band, not partially. A 4pt stem fills the
/// 10pt gap between the core's edge (9pt) and the cap's near edge (19pt) —
/// half of the stem (9–13.5pt) sits inside the label band, half (13.5–19pt)
/// outside, so it's the only occluded ink beyond the core itself. Live
/// pixel count against the Florentin fixture: see `PROGRESS.md`'s worklog
/// for this task — this iteration cleared the ≥50% floor with real margin,
/// the ring iterations did not.
///
/// Total added ink (both caps + both stems) is still well short of the old
/// 44×44 fully-filled marker's — it reads as two small squares on a thin
/// stalk, not a return to a solid block, and the halo stays capped at 30×30
/// inside the 44×44 tap footprint per this file's own §2.3 req 2 bullet 1
/// guarantee, unchanged.
///
/// Also folds in product's secondary, non-blocking finding: the existing
/// pulse read as "under-noticeable" (~2.7% mean luminance swing). Bumped
/// peak halo opacity 0.45 → 0.65 — still well short of the core's full
/// opacity, so the pulse stays a secondary cue, not a second identity
/// element.
private struct LiveEventMarkerGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private let coreSize: CGFloat = 18
    private let haloSize: CGFloat = 30
    private let capSize: CGFloat = 22
    private let stemWidth: CGFloat = 4
    /// Distance from the glyph's center to each cap's center — its near
    /// edge (`capCenterOffset - capSize / 2` = 19pt) clears the measured
    /// ~27pt label's half-height (13.5pt) with margin.
    private let capCenterOffset: CGFloat = 30

    var body: some View {
        ZStack {
            if !reduceMotion {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color("EventMarker"))
                    .frame(width: haloSize, height: haloSize)
                    .opacity(isPulsing ? 0 : 0.65)
                    .scaleEffect(isPulsing ? 1 : 0.6)
            }
            // T-062/PAS-58 label-occlusion fix — static, always fully
            // opaque legibility caps + stems. See the type doc comment
            // above for the geometry/measurement this sizing is based on.
            legibilityArm(direction: -1)
            legibilityArm(direction: 1)
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

    /// One stem+cap, `direction` `-1` for above the core, `1` for below.
    @ViewBuilder
    private func legibilityArm(direction: CGFloat) -> some View {
        let stemLength = capCenterOffset - capSize / 2 - coreSize / 2
        Rectangle()
            .fill(Color("EventMarker"))
            .frame(width: stemWidth, height: stemLength)
            .offset(y: direction * (coreSize / 2 + stemLength / 2))
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color("EventMarker"))
            .frame(width: capSize, height: capSize)
            .offset(y: direction * capCenterOffset)
    }
}
