import SwiftUI

/// The z5 container (TRD §4.7, §2.3) — a `ZStack`-hosted overlay, **not**
/// `.sheet()`, same reason and construction as T-032's original heat modal
/// (D1/D2 there, reused): a system sheet covers the nav row and breaks
/// `ux-flows.md` §2.1's direct-switch rule. `MapScreen` owns its own z3
/// tap-catcher for this surface (D3) — this view draws only the surface
/// itself.
///
/// `SearchSheet/` knows no map and no router (TRD §2.2) — it renders
/// `[SearchResult]` and reports a selection or a dismissal upward by
/// closure. `MapScreen` is the only caller and the only place that knows
/// what `onSelect`/`onDismiss` do to `DetailRouter`/`MapChromeState`/
/// `SearchSession`.
///
/// **T-081/`PAS-76`:** the "Hour" segment this view used to carry
/// (T-078/`PAS-60`'s Search/Hour segmented control, wrapping `HourReadout`/
/// `HourSlider`) is removed — `EdgeHourZone`/`EdgeHourTrack` ("the sides")
/// already write the same `selectedHour` binding `MapScreen` owns, so the
/// in-modal control was redundant. This view now only ever renders Search
/// content; there is no more segmented control to switch away from.
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
            // Full width, top-corners-only (T-079/`PAS-73`,
            // `modal-shape-standard.md` §"the fix") — matches the system
            // `.sheet()` shape Group A already renders, so both groups read
            // as one family. **T-099/`PAS-99`:** `MapNavRow` (z7) is no
            // longer drawn at all while this surface is presented — it used
            // to stay hit-testable above this surface by z-order; that rule
            // is reversed now, see `MapNavRow`'s header comment. This
            // surface's own close button and drag-to-dismiss (plus
            // `MapScreen`'s separate z3 tap-outside-to-dismiss catcher) are
            // the dismiss paths, independent of the nav row either way.
            // T-106/`PAS-106`, Aviran-direct: Liquid Glass, not opaque
            // `Color("Surface")`. Reverses `PAS-27`/T-036's own
            // `.thickMaterial` → opaque fix (translucent-over-map made text
            // unreadable) — deliberately, not rediscovered. Full rationale,
            // the contrast-test blind spot this reintroduces, and the
            // readability tradeoff Aviran accepted: `ModalGlassBackground`'s
            // doc comment (`Support/ModalGlassBackground.swift`).
            .modalGlassBackground()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            // `.ignoresSafeArea(edges: .bottom)` must be the outermost
            // modifier — the true render-space extent it grants only
            // applies to the frame it's attached to. Applied *before* the
            // outer `.frame(maxWidth:maxHeight:alignment:)` (the original,
            // rejected T-079 attempt), the outer frame re-derives its own
            // bottom edge from the safe area regardless, and the card stops
            // 34pt short (`product` REJECT 2026-08-07, measured on iPhone
            // 17/iOS 26.5). Applied last, after that frame, it's the final
            // modifier's extent that reaches the true bottom edge.
            //
            // **`PAS-78` fix — scoped to `.container` only, not the default
            // `.all`.** The unscoped `.ignoresSafeArea(edges: .bottom)`
            // ignores the *keyboard's* bottom safe area too, so once the
            // search field has focus and the keyboard is up, this card's
            // layout never shrinks or shifts for it — `resultsArea`'s rows
            // keep rendering flush with the screen's true bottom edge,
            // straight underneath the system keyboard window (confirmed by
            // dumping the live accessibility tree during
            // `SearchResultRowTapInvestigationTests`: the keyboard's own
            // window spans `{0, 583}`–`{402, 874}`, and the tapped row
            // rendered at `{16, 825.7}`–`{386, 869.7}`, entirely inside
            // it). The keyboard is a separate, topmost system window —
            // XCUITest's own `isHittable` only reasons about the app's
            // hierarchy, so it reports `true` right up until the real touch
            // reaches the OS, which routes it to the keyboard window
            // instead and the app never sees it. Scoping to `.container`
            // keeps this card flush against the true bottom edge exactly as
            // before *only* for the home-indicator/container safe area
            // (T-079's original fix, still intact — confirmed no
            // regression against the T-079 shrink-to-fit tests; the Hour
            // segment's own rendered regression suite that used to be
            // rerun here, `testHourSegmentContentStaysUnoccludedAndContainedAcrossTextSizes`,
            // no longer exists as of T-081/`PAS-76`), while now respecting the
            // keyboard's own safe-area inset — so the card's rendered
            // frame shrinks above the keyboard while it's showing, and
            // `resultsArea`'s rows never end up rendered underneath it.
            .ignoresSafeArea(.container, edges: .bottom)
            // Queryable container frame (was `hourSegmentCard`, C16, T-077/
            // `PAS-51`) — renamed at T-081/`PAS-76` since the Hour segment
            // it was named for no longer exists; this view only ever
            // renders Search content now, and the identifier follows.
            // `.accessibilityElement(children: .contain)` mirrors
            // `MapNavRow.swift`'s own identical need — an identifier alone
            // doesn't surface a plain SwiftUI container as a queryable
            // element; `.contain` does, without hiding the search field/
            // chip row/result rows beneath it.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("searchOverlayCard")
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

    /// **T-099/`PAS-99`:** since `MapNavRow` is hidden while this overlay is
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
