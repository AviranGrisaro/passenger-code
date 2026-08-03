import SwiftUI

/// The z5 container (TRD §4.7, §2.3) — a `ZStack`-hosted overlay, **not**
/// `.sheet()`, same reason and construction as T-032's heat modal (D1/D2
/// there, reused): a system sheet covers the nav row and breaks
/// `ux-flows.md` §2.1's direct-switch rule. `MapScreen` owns its own z3
/// tap-catcher for this surface (D3) — this view draws only the surface
/// itself.
///
/// `SearchSheet/` knows no map and no router (TRD §2.2) — it renders
/// `[SearchResult]` and reports a selection or a dismissal upward by
/// closure. `MapScreen` is the only caller and the only place that knows
/// what `onSelect`/`onDismiss` do to `DetailRouter`/`MapChromeState`/
/// `SearchSession`.
struct SearchOverlay: View {
    @Bindable var session: SearchSession
    let results: [SearchResult]
    let onSelect: (SearchResult) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    /// Two heights, not system detents (D2) — this is an overlay, not a
    /// `.sheet`, per D1. `compact` is the fresh-open height.
    private static let compactFraction: CGFloat = 0.45
    private static let expandedFraction: CGFloat = 0.92
    /// Handle-drag distance past which the surface toggles height or
    /// dismisses (D2) — a Fitts's-Law-scale gesture threshold, not a literal
    /// system detent.
    private static let toggleThreshold: CGFloat = 60
    private static let dismissThreshold: CGFloat = 120

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height * (isExpanded ? Self.expandedFraction : Self.compactFraction)
            VStack(alignment: .leading, spacing: 0) {
                dragHandle
                header
                CategoryChipRow(filter: session.filter) { category in
                    session.filter = session.filter.toggling(category)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                resultsArea
            }
            .frame(width: geometry.size.width, height: height, alignment: .top)
            .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
        .animation(.easeOut(duration: reduceMotion ? 0 : 0.25), value: isExpanded)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.secondary)
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture().onEnded(handleDragEnd))
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            SearchFieldRow(text: $session.text)
            closeButton
        }
        .padding(.horizontal)
        .padding(.top, 4)
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
    private var resultsArea: some View {
        if session.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, session.filter == .all {
            SearchEmptyStates.emptyField()
        } else if results.isEmpty {
            SearchEmptyStates.noMatch(query: session.text)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { result in
                        Button {
                            onSelect(result)
                        } label: {
                            SearchResultRow(result: result)
                                .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        let translation = value.translation.height
        if translation > Self.dismissThreshold {
            onDismiss()
        } else if translation > Self.toggleThreshold {
            isExpanded = false
        } else if translation < -Self.toggleThreshold {
            isExpanded = true
        }
    }
}
