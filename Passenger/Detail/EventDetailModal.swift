import SwiftUI

/// The event depth-1 destination (TRD §4.7, D6). Always depth 1 — events
/// don't participate in `placeDepth` and never nest under a Hood sheet; an
/// event replaces whatever was open (`DetailRouter.openEvent`), matching
/// `openHood`'s own swap-in-place behaviour.
///
/// Handed a `LiveEvent` by value, so this needs no new environment
/// injection beyond what's already applied at the sheet site. `hoodName` is
/// the one exception (T-052/PAS-40, PRD req 4: "a Hood renders its display
/// name, never its slug") — `LiveEvent.hoodID` is a raw slug with no `Hood`
/// object attached, so the caller (`MapScreen`, which already holds the
/// loaded `[Hood]` list) resolves it once and hands the display name in by
/// value, the same "no new environment dependency" shape TRD §4.7 chose for
/// everything else here. `nil` means the slug didn't resolve against the
/// loaded Hood list — the row is omitted rather than falling back to the raw
/// id, since showing the raw id is exactly what req 4 forbids.
///
/// **No longer presented via `.sheet()` (T-079/`PAS-73` re-fix, `product`
/// REJECT 2026-08-07).** The spec's original premise — a system `.sheet()`
/// is full-width/flush-bottom/top-corners-only by default — is false on iOS
/// 26: a `.sheet()` renders as a floating card rounded on all 4 corners at
/// *every* detent, including `.large` (measured directly on iPhone 17/iOS
/// 26.5 — a first attempt at this fix tried `.presentationDetents([.large])`
/// alone and it did **not** produce the required shape, confirmed by
/// screenshot, not assumed). No SwiftUI API on this toolchain forces the
/// old page-style full-bleed sheet shape back. So this view now owns its
/// own presentation, the same `ZStack`-scrim-plus-flush-card construction
/// `PlacesListOverlay`/`PassportSurface` already use (Group B) — `MapScreen`
/// places it in a plain `.overlay`, not a `.sheet`, see that file's comment.
struct EventDetailModal: View {
    let event: LiveEvent
    let hoodName: String?

    @Environment(DetailRouter.self) private var router
    @Environment(\.directionsService) private var directionsService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0

    /// Downward drag distance past which a release dismisses — same value
    /// as `PlacesListOverlay`'s/`PassportSurface`'s identical gesture.
    private static let dismissDragThreshold: CGFloat = 80

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { router.closeEvent() }

            card
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > Self.dismissDragThreshold {
                                router.closeEvent()
                            }
                        }
                )
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            dragHandle
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    ForEach(EventDetailRows.rows(for: event), id: \.self) { row in
                        rowView(for: row)
                    }
                    Spacer(minLength: 0)
                    routeButton
                }
                .padding()
            }
            // Capped like `HoodSheet`'s own scrollable content (same 480pt
            // ceiling, T-079/PAS-73 round-3 fix) — this card is now
            // intrinsically sized, not detent-driven, so an uncapped card
            // would expand to fill nearly the whole screen instead of
            // leaving the map visible underneath it.
            // `.fixedSize` makes the frame clamp an *ideal* height instead of
            // inflating a *proposed* one, so short content shrinks to fit
            // instead of always claiming the full 480pt (PAS-77).
            .frame(maxHeight: 480)
            .fixedSize(horizontal: false, vertical: true)
        }
        // Full width, flush to the bottom edge, top-corners-only — matches
        // Group B's own shape exactly (see that construction's comment for
        // the modifier-order reasoning this one follows).
        // T-106/`PAS-106`, Aviran-direct: Liquid Glass, not opaque
        // `Color("Surface")`. Reverses `PAS-27`/T-036's own
        // `.thickMaterial` → opaque fix (translucent-over-map made text
        // unreadable) — deliberately, not rediscovered. Full rationale,
        // the contrast-test blind spot this reintroduces, and the
        // readability tradeoff Aviran accepted: `ModalGlassBackground`'s
        // doc comment (`Support/ModalGlassBackground.swift`).
        .modalGlassBackground()
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.secondary)
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(event.name)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                // Stable hook for UI tests, same reason `placeDetailTitle`/
                // `hoodSheetTitle` exist — proves the modal rendered *and*
                // is showing the right event's content.
                .accessibilityIdentifier("eventDetailTitle")
            Spacer()
            closeButton
        }
    }

    private var closeButton: some View {
        Button {
            router.closeEvent()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))  // 32pt visual glyph
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)  // in a 44x44pt target
        }
        .accessibilityLabel("Close")
    }

    /// Req 4 bullet 3 made structural (TRD §4.7): the `.name` case is
    /// already shown in `header` above, so it renders nothing a second time
    /// here. Every other case is data-driven off `EventDetailRows.rows(for:)`
    /// — a `nil` field never reaches this `switch` at all, because the row
    /// simply isn't in the array.
    @ViewBuilder
    private func rowView(for row: EventDetailRows.Row) -> some View {
        switch row {
        case .name:
            EmptyView()
        case .time:
            Label(event.timeLabel, systemImage: "clock")
                .foregroundStyle(.secondary)
        case .venue:
            if let venueName = event.venueName {
                Label(venueName, systemImage: "mappin.and.ellipse")
                    .foregroundStyle(.secondary)
            }
        case .hood:
            // `EventDetailRows.rows(for:)` includes `.hood` whenever
            // `event.hoodID != nil` — that's the "a hood field is present"
            // check. Whether it *renders* also requires the slug to have
            // resolved to a display name (see the type doc comment above);
            // an unresolved slug falls through this `if let` and the row
            // draws nothing, same graceful-degradation shape every other
            // optional field here already uses.
            if let hoodName {
                Label(hoodName, systemImage: "map")
                    .foregroundStyle(.secondary)
            }
        case .category:
            if let category = event.category {
                Label(EventDetailRows.displayCategory(category), systemImage: "tag")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var routeButton: some View {
        let availableApps = directionsService.availableApps()
        return VStack(spacing: 4) {
            Button {
                // `closeEvent()`, then hand off — same shape as
                // `PlaceDetailModal`'s route button (TRD §4.7): the shipped
                // `DirectionsService` is reused unchanged, walking mode set
                // in the one place the service sets it.
                router.closeEvent()
                guard let app = availableApps.first else { return }
                directionsService.open(app, to: RouteDestination(name: event.name, coordinate: event.coordinate))
            } label: {
                Text("Directions")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(availableApps.isEmpty)

            // Unreachable in production (Apple Maps cannot be uninstalled),
            // but the PRD requires the empty case be handled, not assumed
            // impossible — same as `PlaceDetailModal`'s own route button.
            if availableApps.isEmpty {
                Text("No walking-directions app is available on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
