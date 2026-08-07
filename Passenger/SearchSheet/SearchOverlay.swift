import SwiftUI

/// The z5 container (TRD §4.7, §2.3) — a `ZStack`-hosted overlay, **not**
/// `.sheet()`, same reason and construction as T-032's original heat modal
/// (D1/D2 there, reused): a system sheet covers the nav row and breaks
/// `ux-flows.md` §2.1's direct-switch rule. `MapScreen` owns its own z3
/// tap-catcher for this surface (D3) — this view draws only the surface
/// itself.
///
/// **T-078/`PAS-60` reopened (`nav-row-v2-redesign.md` §1):** this view now
/// also owns the "Hour" segment — the map-hour slider that used to be its
/// own standalone `HeatModalCard`/`HeatButton` surface. A top segmented
/// control (`Search`/`Hour`, defaulting to `Search`) swaps the whole content
/// area between the two; `chrome.presented == .search` covers both, since
/// there is no longer an independent `.heat` chrome state. `HourReadout`/
/// `HourSlider` are reused as private subviews of the Hour segment, not
/// duplicated — `MapScreen` still owns the one `selectedHour` binding and
/// the one `HourFormat.Readout`, threaded through exactly as it used to feed
/// `HeatModalCard`.
///
/// `SearchSheet/` knows no map and no router (TRD §2.2) — it renders
/// `[SearchResult]` and reports a selection or a dismissal upward by
/// closure. `MapScreen` is the only caller and the only place that knows
/// what `onSelect`/`onDismiss` do to `DetailRouter`/`MapChromeState`/
/// `SearchSession`.
struct SearchOverlay: View {
    @Bindable var session: SearchSession
    let results: [SearchResult]
    @Binding var selectedHour: Int
    let hourReadout: HourFormat.Readout
    let onSelect: (SearchResult) -> Void
    let onDismiss: () -> Void

    /// The two segments this surface now covers (§1 above). `.search` is
    /// the default — search is the higher-frequency action, per the design
    /// spec's Hick's-Law reasoning; Hour stays one tap away, never hidden.
    private enum Segment: Hashable {
        case search, hour
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var segment: Segment = .search

    /// Same ceiling `HeatModalCard` used to apply to its own content (F2,
    /// `PAS-51` finding 2) — `HourReadout`'s offset numeral and "next day"
    /// pill still need a cap to avoid mid-token wrap at AX5, and this
    /// surface's height is now a fixed screen fraction rather than
    /// content-sized, so an uncapped Hour segment could clip inside it.
    /// Scoped to the Hour segment's own content, not the whole overlay —
    /// Search's result rows scroll and have no such ceiling today.
    private static let maxDynamicTypeSize: DynamicTypeSize = .accessibility3

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
                segmentPicker
                switch segment {
                case .search:
                    header
                    CategoryChipRow(filter: session.filter) { category in
                        session.filter = session.filter.toggling(category)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    resultsArea
                case .hour:
                    hourContent
                }
            }
            .frame(width: geometry.size.width, height: height, alignment: .top)
            // Full width, top-corners-only (T-079/`PAS-73`,
            // `modal-shape-standard.md` §"the fix") — matches the system
            // `.sheet()` shape Group A already renders, so both groups read
            // as one family. `MapNavRow` (z7, drawn last in `MapScreen`)
            // still renders and stays hit-testable above this surface by
            // z-order, not by this card stopping short of the row.
            .background(
                Color("Surface"),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 20, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 20,
                    style: .continuous
                )
            )
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
            .ignoresSafeArea(edges: .bottom)
            // C16 (TRD §9 row 5b, T-077/`PAS-51`) — the one identifier the
            // T-078 merge dropped. Lets a UI test grab this fixed-fraction
            // card's own frame for the containment checks row 5b(ii) needs;
            // never used for a card-frame equality or separation assertion
            // (§9 standing rule, new at v6) since this frame is identical at
            // every text size by construction. `.accessibilityElement(children:
            // .contain)` mirrors `MapNavRow`'s own identical need (`MapNavRow
            // .swift`) — an identifier alone doesn't surface a plain SwiftUI
            // container as a queryable element; `.contain` does, without
            // hiding the segment picker/search field/slider children beneath it.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("hourSegmentCard")
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

    /// Search/Hour, defaulting to `.search` (nav-row-v2-redesign.md §1) —
    /// the single visible entry point that replaced the standalone Heat
    /// button. A visible control, not a hidden gesture, per that spec's
    /// Poka-Yoke reasoning.
    private var segmentPicker: some View {
        Picker("", selection: $segment) {
            Text("Search").tag(Segment.search)
            Text("Hour").tag(Segment.hour)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 4)
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

    /// The Hour segment (T-078) — `HeatModalCard`'s former `header`/
    /// `content`, reused as-is: same title, same close button, same
    /// `HourReadout`/`HourSlider` pairing.
    private var hourContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Map hour")
                    .font(.title2.bold())
                    .foregroundStyle(Color("MutedOnSurface"))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("hourSegmentTitle")
                Spacer()
                closeButton
            }
            .padding()
            VStack(alignment: .leading, spacing: 16) {
                HourReadout(readout: hourReadout)
                HourSlider(selectedHour: $selectedHour, readout: hourReadout)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .dynamicTypeSize(...Self.maxDynamicTypeSize)
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
