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
/// **T-062/PAS-58, round 3 post-ship redesign (2026-08-04):** the glyph was
/// replaced again, and the whole 44×44 tap target now carries a small
/// vertical nudge — see `LiveEventMarkerGlyph` and `markerVerticalNudge`
/// below. The `Annotation`/`Button`/accessibility structure is otherwise
/// untouched.
struct EventLayer: MapContent {
    let event: LiveEvent
    let action: () -> Void

    /// **T-062/PAS-58 round 3.** Round 2's fix kept the drawn ink centered on
    /// `event.coordinate` and grew it outward (caps on stems) until enough of
    /// it escaped a same-centered Hood label — which is what put visible ink
    /// outside the still-centered 44×44 tap frame and caused round 2's
    /// REJECT (PRD req 4 bullet 2). Round 3 goes the other way: keep the
    /// glyph a single compact shape (see below) and move the *whole* 44×44
    /// hosting box — frame and content together — down by this amount, so
    /// whatever is visible and whatever is tappable never separate.
    ///
    /// **First attempt, live-measured, reverted:** `.offset(y:)` applied to
    /// the `Button` itself. That moved the *drawn* content correctly (the
    /// pixel-visibility measurement below was taken against that build and
    /// held), but live tap-testing at the Florentin fixture showed
    /// `MapKit`'s `Annotation` sizes its hosting/hit-test box from the
    /// content's *un-offset* 44×44 frame — `.offset()` is a rendering-only
    /// transform in this hosting context, so the bottom ~14pt of the visibly
    /// shifted diamond fell outside the hosting box's hit region and taps
    /// there fell through to `HoodLayer` underneath. The exact defect PRD
    /// req 4 bullet 2 exists to catch, just reached through the nudge
    /// instead of through round 2's caps-on-stems. Caught live, not
    /// asserted — see this task's `PROGRESS.md` worklog entry.
    ///
    /// **Fix:** `Annotation`'s own `anchor:` parameter instead of an
    /// in-content offset. Anchor picks which point of the (still-44×44,
    /// still-unmodified) content box coincides with `event.coordinate` —
    /// moving it doesn't resize or transform the content, it repositions
    /// the *whole* box MapKit hosts and hit-tests, so content and hit
    /// region can't diverge. An anchor `y` below the box's own center
    /// (`0.5 − nudge/boxHeight`) puts the coordinate near the box's top
    /// edge, which pushes the box — and everything in it — down by `nudge`
    /// on screen.
    /// **Not private** (PAS-79 fix, 2026-08-07): `MapScreen.handleTap`'s
    /// `SpatialTapGesture` fallback needs this exact value too — see its own
    /// use site for why.
    static let markerVerticalNudge: CGFloat = 18
    private let markerBoxHeight: CGFloat = 44

    private var markerAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: 0.5 - Self.markerVerticalNudge / markerBoxHeight)
    }

    var body: some MapContent {
        Annotation(event.name, coordinate: event.coordinate, anchor: markerAnchor) {
            Button(action: action) {
                LiveEventMarkerGlyph()
                    .frame(width: 44, height: markerBoxHeight)  // Fitts's Law minimum (design-principles.md §2) — tap target size unchanged across every T-062 round
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

/// The glyph drawn inside `EventLayer`'s 44×44 tap target.
///
/// **T-062/PAS-58, round 3 (2026-08-04).** Founder-direct feedback on round
/// 2's shipped shape (18×18 core + two 22×22 "legibility caps" on thin
/// stems, `PROGRESS.md` L-002 stub): "what is this live event icon? please
/// fix it. review locali assets i like the live events icon there." The
/// caps-on-stems shape is exactly what `product`'s own round-2 REJECT called
/// "a barbell/chain-link... brackets decorating the Hood label rather than
/// its own object" — Aviran is naming the same defect from the other side of
/// the desk. Round 3 abandons that shape entirely rather than tuning it.
///
/// `chief-of-staff` pulled the old Locali app's live-event marker
/// (`Locali/Features/Map/EventMarker.swift`, frozen at
/// `github.com/AviranGrisaro/locali`) as the concrete reference: a single
/// 22×22 rounded square rotated 45° into a diamond, filled solid, a white
/// `calendar` SF Symbol centered on it, and a soft pulsing halo behind it —
/// one gestalt object, no stacked shapes, no stems. Passenger's
/// `Color("EventMarker")` (dark purple/navy) is already the same colour
/// family as Locali's violet, so only the shape/icon needed to change to
/// match the look Aviran is asking for.
///
/// - **One shape, not a stack.** A single 22×22 `RoundedRectangle` rotated
///   45° into a diamond. Kept the diamond over round 2's rounded square —
///   Locali's own reference shape, and distinct in silhouette from
///   `PlaceLayer`'s `Circle` even in greyscale (`design-principles.md` §3,
///   "never rely on color alone" — same reasoning round 1/2 already
///   established, still true here since the icon/shape pairing is what
///   carries it, not the outline that's gone now).
/// - **A glyph, not a bare shape.** Round 1 dropped `PlaceLayer`'s Circle for
///   a solid shape and *removed* the glyph entirely (`sparkles`, judged
///   "airy/thin"); round 3 restores a glyph — Locali's white `calendar`
///   SF Symbol, `.system(size: 12, weight: .semibold)` — because a solid
///   diamond alone reads as a generic marker shape shared with nothing in
///   particular, and `calendar` is the one glyph in SF Symbols that reads
///   "event" without a caption. Semibold at 12pt against a 22pt fill keeps
///   the glyph legible without threatening to overflow the diamond's
///   inscribed circle (side 22 → inradius 11pt, comfortably larger than the
///   glyph's own cap height at this point size).
/// - **Micro-animation kept, not restored to Locali's exact curve.** Locali
///   pulsed a halo's *opacity* only (0.25↔0.5, 1s `easeInOut`, autoreverse).
///   Round 2's scale+fade "burst" halo (`easeOut`, 1.6s, no autoreverse) is
///   kept as-is rather than reverted — it already satisfies the founder's
///   original "micro animation that will let the user know there's a live
///   event" ask (2026-08-04 L-002 stub) and nothing in this round's feedback
///   said the *motion* was wrong, only the *shape*. Halo capped at 34×34,
///   inside the 44×44 tap footprint, so it still can't compete with heat's
///   area channel (§2.3 req 2 bullet 1, unchanged across every round).
///   Disabled outright under Reduce Motion: the halo view isn't built at
///   all, core renders solid/static (`design-principles.md` §3, "respect
///   `prefers-reduced-motion`").
///
/// **Occlusion (PRD req 1's marker-legibility bullet) is handled entirely by
/// `EventLayer.markerVerticalNudge`, not by this glyph's own geometry** —
/// unlike round 2, this shape makes no attempt to out-reach the Hood label
/// on its own. See that property's comment for why, and this task's
/// `PROGRESS.md` worklog entry for the live pixel measurement at the seeded
/// Florentin fixture.
private struct LiveEventMarkerGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private let coreSize: CGFloat = 22
    private let haloSize: CGFloat = 34
    private let iconSize: CGFloat = 12

    var body: some View {
        ZStack {
            if !reduceMotion {
                diamond
                    .opacity(isPulsing ? 0 : 0.5)
                    .scaleEffect(isPulsing ? 1 : 0.65)
                    .frame(width: haloSize, height: haloSize)
            }
            diamond
                .frame(width: coreSize, height: coreSize)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            Image(systemName: "calendar")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }

    private var diamond: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color("EventMarker"))
            .rotationEffect(.degrees(45))
    }
}
