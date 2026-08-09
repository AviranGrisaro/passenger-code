import SwiftUI

/// The z5 container (TRD §4.5) — a `ZStack` layer, **not** `.sheet()`, same
/// reason and construction as T-032's `HeatModalCard` (D2 there, reused): a
/// system sheet covers the nav row and breaks `ux-flows.md` §2.1's
/// direct-switch rule. Owns its own scrim (T-032's z3 construction —
/// `Color.black.opacity(…)`, tap → dismiss) rather than sharing a component,
/// mirroring how `HeatModalCard` owns its scrim.
///
/// `PlacesList/` knows no fetching, no persistence, and no router internals
/// (TRD §2.3) — it renders `[PlacesListEntry]` and reports a tapped `Place`.
/// `MapScreen` is the only caller, and the only place that knows what
/// `onSelect`/`onDismiss` do to `DetailRouter`/`MapChromeState` (D8).
struct PlacesListOverlay: View {
    let entries: [PlacesListEntry]
    let onSelect: (Place) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0

    /// Downward drag distance past which a release dismisses (TRD §4.5).
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
        // 2026-08-07) — a child's `ignoresSafeArea()` only extends the
        // render space of the frame it's directly attached to, and `card`
        // here is an intrinsically-sized `VStack` aligned to the ZStack's
        // bottom edge, not a frame that itself reaches the screen edge.
        // Applied to the `ZStack` (the container `card` is aligned within),
        // the whole layer's true bottom edge moves to the screen's actual
        // last pixel row, and `card`'s `.bottom` alignment follows it there.
        // Measured 34pt short (the home-indicator inset) before this fix.
        .ignoresSafeArea(edges: .bottom)
        // Reduce Motion collapses the transition to 0 duration rather than
        // skipping the state change (TRD §4.5) — the view is still
        // inserted/removed, it just doesn't animate doing so.
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
        // the bottom edge, top-corners-only — matches the system `.sheet()`
        // shape Group A already renders (`EventDetailModal`/
        // `PlaceDetailModal`/`HoodSheet`), so both groups read as one
        // family instead of the old floating/inset card. **T-099/`PAS-99`:**
        // `MapNavRow` (z7) is no longer drawn at all while this surface is
        // presented — it used to stay hit-testable above this surface by
        // z-order; that rule is reversed now, see `MapNavRow`'s header
        // comment. This surface's own scrim/close button/drag (above) are
        // the dismiss paths, independent of the nav row either way.
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
            Text("Places")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer()
            closeButton
        }
        .padding()
    }

    /// **T-099/`PAS-99`:** since `MapNavRow` is hidden while this list is
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

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            PlacesListEmptyState(onExplore: onDismiss)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        PlacesListRow(entry: entry) { onSelect(entry.place) }
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .frame(maxHeight: 480)
        }
    }
}
