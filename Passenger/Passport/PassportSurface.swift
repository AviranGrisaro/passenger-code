import SwiftUI

/// The z5 container (passport TRD §4.6) — a `ZStack` layer, **not** a
/// system sheet, same reason and construction as T-036's
/// `PlacesListOverlay` and T-032's `HeatModalCard`: a system sheet covers
/// the nav row and breaks `ux-flows.md` §2.1's direct-switch rule. Owns its
/// own scrim rather than sharing a component, mirroring `PlacesListOverlay`.
///
/// Opaque `Color("Surface")` background, not `.glassEffect()` or a
/// `Material` — this card sits directly over the live map, and
/// `design-principles.md`'s contrast-verifiability rule (the lesson behind
/// T-036's own `.thickMaterial` → `Color("Surface")` fix) rules out
/// translucent chrome over dynamic content here for the same reason.
///
/// No sticker and no Hood row is tappable in V1 (D10) — the ✕ and the drag
/// handle are the only interactive elements, so there is no path from this
/// surface into a depth-1 modal, unlike `PlacesListOverlay`.
struct PassportSurface: View {
    let stickers: [PassportSticker]
    let progress: [HoodProgress]
    let isOverallLocal: Bool
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0

    /// Downward drag distance past which a release dismisses — same value as
    /// `PlacesListOverlay`'s identical gesture.
    private static let dismissDragThreshold: CGFloat = 80

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            card
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > Self.dismissDragThreshold {
                                onDismiss()
                            }
                        }
                )
        }
        // `.ignoresSafeArea(edges: .bottom)` belongs on the outer `ZStack`,
        // not nested on `card` (T-079/`PAS-73` re-fix, `product` REJECT
        // 2026-08-07, same fix as `PlacesListOverlay`'s identical
        // construction) — a child's `ignoresSafeArea()` only extends the
        // render space of the frame it's directly attached to, and `card`
        // here is an intrinsically-sized `VStack` aligned to the ZStack's
        // bottom edge, not a frame that itself reaches the screen edge.
        // Applied to the `ZStack` (the container `card` is aligned within),
        // the whole layer's true bottom edge moves to the screen's actual
        // last pixel row, and `card`'s `.bottom` alignment follows it there.
        .ignoresSafeArea(edges: .bottom)
        // Reduce Motion collapses the transition to 0 duration rather than
        // skipping the state change — the view is still inserted/removed,
        // it just doesn't animate doing so (TRD §4.6).
        .transition(
            AnyTransition.move(edge: .bottom).combined(with: .opacity)
                .animation(.easeOut(duration: reduceMotion ? 0 : 0.25))
        )
    }

    private var card: some View {
        VStack(spacing: 0) {
            dragHandle
            header
            content
        }
        // T-079/`PAS-73` (`modal-shape-standard.md`): full width, flush to
        // the bottom edge, top-corners-only — matches the shape the system
        // sheet presenter (Group A: `EventDetailModal`/`PlaceDetailModal`/
        // `HoodSheet`) already renders, so both groups read as one family
        // instead of the old floating/inset card. **T-099/`PAS-99`:**
        // `MapNavRow` (z7) is no longer drawn at all while this surface is
        // presented — it used to stay hit-testable above this surface by
        // z-order; that rule is reversed now, see `MapNavRow`'s header
        // comment. This surface still owns its own presentation (per the
        // header comment above) — matching shape only, not adopting the
        // presenter, and its own scrim/close button/drag (above) are the
        // dismiss paths, independent of the nav row either way.
        // (`.ignoresSafeArea` itself lives on `body`'s outer `ZStack`, not
        // here — see that modifier's comment for why.)
        .background(
            Color("Surface"),
            in: UnevenRoundedRectangle(
                topLeadingRadius: 20, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 20,
                style: .continuous
            )
        )
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.secondary)
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack {
            Text("Passport")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("passportSurfaceTitle")
            Spacer()
            closeButton
        }
        .padding()
    }

    /// **T-099/`PAS-99`:** since `MapNavRow` is hidden while Passport is
    /// presented, this is now the primary dismiss affordance for VoiceOver
    /// and Switch Control users, not only for touch — a plain `Button`,
    /// never `.accessibilityHidden`, reachable through the same
    /// accessibility tree either technology reads. See `MapNavRow`'s header
    /// comment for the full reasoning.
    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))  // 32pt visual glyph
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)  // in a 44x44pt target
        }
        .accessibilityLabel("Close")
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !progress.isEmpty {
                    PassportProgressList(progress: progress, isOverallLocal: isOverallLocal)
                }
                PassportAlbum(stickers: stickers)
            }
            .padding()
        }
        // `.fixedSize` makes the frame clamp an *ideal* height instead of
        // inflating a *proposed* one, so short content shrinks to fit
        // instead of always claiming the full 480pt. Group A picked this up
        // at PAS-77; this surface and `PlacesListOverlay` kept the bare
        // `maxHeight` and so still rendered a half-empty card.
        .frame(maxHeight: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}
