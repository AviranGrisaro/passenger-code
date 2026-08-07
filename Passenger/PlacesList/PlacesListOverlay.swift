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
        // family instead of the old floating/inset card. `MapNavRow` (z7,
        // drawn last in `MapScreen`) still renders and stays hit-testable
        // above this surface by z-order, not by this card stopping short of
        // the row.
        .background(
            Color("Surface"),
            in: UnevenRoundedRectangle(
                topLeadingRadius: 20, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 20,
                style: .continuous
            )
        )
        .ignoresSafeArea(edges: .bottom)
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
