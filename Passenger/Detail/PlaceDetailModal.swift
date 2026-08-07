import SwiftUI

/// The depth-1-or-2 place destination (TRD §4.8, §4.2). Nothing else in this
/// modal navigates anywhere (PRD req 3) — no closed-place badge, no
/// provenance word, no Places-list row; all T-036's.
///
/// **No longer presented via `.sheet()` (T-079/`PAS-73` re-fix)** — see
/// `EventDetailModal`'s identical doc comment for the full iOS 26 Liquid
/// Glass rationale (a `.sheet()` renders inset/all-4-corners-rounded at
/// every detent, `.large` included). This view owns its own scrim and card
/// now, Group-B-style. It's placed identically at both presentation sites:
/// Site A (`MapScreen`, top-level, its own scrim sits over the map) and
/// Site B (nested inside `HoodSheet`, its own scrim sits over the Hood
/// card) — the same construction works unmodified at both depths, since
/// depth only changes *what's visually underneath*, never this view's own
/// shape or dismiss behavior.
struct PlaceDetailModal: View {
    let place: Place
    /// scenic-walk (T-057): the corridor candidate search needs every
    /// Hood's geometry and flag, which `MapScreen` already loaded — passed
    /// in rather than re-fetched, the same reason `place` itself is a plain
    /// value parameter and not an environment lookup.
    let hoods: [Hood]

    @Environment(SavedPlacesStore.self) private var savedPlaces
    @Environment(DetailRouter.self) private var router
    @Environment(\.directionsService) private var directionsService
    @Environment(PlaceCatalog.self) private var placeCatalog
    // scenic-walk (T-057, TRD §4.10): one app-lifetime instance, injected by
    // `MapScreen` — not created here (TRD §4.4, A2).
    @Environment(RoutePreviewModel.self) private var routePreviewModel
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
                .onTapGesture {
                    // `closePlace()`, not `closeHood()` — same reasoning as
                    // `closeButton` below: a scrim tap should behave exactly
                    // like the ✕, and dismiss-one-level is this view's own
                    // contract regardless of how the scrim was reached.
                    router.closePlace()
                }

            card
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > Self.dismissDragThreshold {
                                router.closePlace()
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
        .task(id: place.id) {
            await routePreviewModel.resolve(for: place, hoods: hoods, places: placeCatalog.allPlaces)
        }
        .onDisappear {
            // TRD §4.4: "torn down on dismiss" — the shared, long-lived
            // model's state is cleared the moment this modal leaves the
            // hierarchy, so `RouteLayer` on the map behind it stops drawing
            // this place's route immediately rather than leaving it stale
            // until the next resolve.
            routePreviewModel.reset()
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            dragHandle
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    categoryRow
                    touristTrapSlot
                    Spacer(minLength: 0)
                    RouteControls(model: routePreviewModel)
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
        // Group B's own shape exactly.
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
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(place.name)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                // Stable hook for UI tests (T-033/PAS-13 fix pass) — proves
                // the modal rendered *and* is showing the right place's
                // content, not just that it's on screen.
                .accessibilityIdentifier("placeDetailTitle")
            Spacer()
            saveButton
            closeButton
        }
    }

    private var saveButton: some View {
        let isSaved = savedPlaces.isSaved(place.id)
        // Renders `savedPlaces.isSaved(place.id)` directly off the store —
        // never a local `@State` mirror (TRD §4.4). Never a checkmark: the
        // glyph pair is bookmark/bookmark.fill.
        return Button {
            savedPlaces.toggle(place.id)
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(isSaved ? "Saved" : "Save")
    }

    private var closeButton: some View {
        Button {
            // `closePlace()`, never `closeHood()` — at depth 1 `hood` is
            // already `nil`, so this is a full dismiss; at depth 2 it leaves
            // the Hood sheet standing, "exactly one level up" (TRD §5).
            router.closePlace()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))  // 32pt visual glyph
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)  // in a 44x44pt target
        }
        .accessibilityLabel("Close")
    }

    private var categoryRow: some View {
        Label(place.category.displayName, systemImage: place.category.symbolName)
            .foregroundStyle(.secondary)
    }

    /// tourist-trap-flag TRD §4.2 row 2, §11 C7: one line, only when flagged
    /// — `false`/`nil` render nothing and take zero height, same footprint
    /// the placeholder `EmptyView()` occupied before this task. Independent
    /// of `permanentlyClosed` (T-036) — no shared condition, no shared copy.
    @ViewBuilder
    private var touristTrapSlot: some View {
        if place.isTouristTrap == true {
            Label(FlagCopy.placeLine, systemImage: "camera.fill")
                .font(.subheadline)
                .foregroundStyle(Color("Flag"))
        }
    }

    private var routeButton: some View {
        let availableApps = directionsService.availableApps()
        return VStack(spacing: 4) {
            Button {
                // The hand-off calls `closeHood()` before opening the
                // external app (TRD §4.6) — clears both fields regardless of
                // depth, so returning from Maps shows the map with every
                // sheet closed (TRD §5).
                router.closeHood()
                guard let app = availableApps.first else { return }
                directionsService.open(app, to: RouteDestination(name: place.name, coordinate: place.coordinate))
            } label: {
                Text("Directions")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(availableApps.isEmpty)

            // Unreachable in production (Apple Maps cannot be uninstalled),
            // but the PRD requires the empty case be handled, not assumed
            // impossible (TRD §4.6).
            if availableApps.isEmpty {
                Text("No walking-directions app is available on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
