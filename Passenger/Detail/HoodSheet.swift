import SwiftUI

/// Presentation site A's Hood destination (TRD §4.8, §4.2). Reads
/// `PlaceCatalog`/`DetailRouter` from the environment — no fetch, no local
/// copy of anything: `places(in:)`/`blurb(for:)` are dictionary reads against
/// already-fetched data.
///
/// **No longer presented via `.sheet()` (T-079/`PAS-73` re-fix)** — see
/// `EventDetailModal`'s doc comment for the full iOS 26 Liquid Glass
/// rationale. This view now owns its own scrim and card (Group-B-style),
/// and Site B's nested depth-2 `PlaceDetailModal` — previously a `.sheet`
/// attached to this view — is now just embedded directly as a further
/// `ZStack` layer above this view's own card: `PlaceDetailModal` supplies
/// its *own* scrim and card (it's the same view used unmodified at Site A),
/// so the visual result is two stacked scrim+card pairs, matching what two
/// nested system sheets used to look like, just both now flush/full-width/
/// top-corners-only instead of floating.
struct HoodSheet: View {
    let hood: Hood
    /// scenic-walk (T-057): threaded through to Site B's nested
    /// `PlaceDetailModal` below, same reason `MapScreen` passes it at Site A
    /// — the corridor search needs every Hood's geometry, not just this one.
    let hoods: [Hood]

    @Environment(PlaceCatalog.self) private var placeCatalog
    @Environment(DetailRouter.self) private var router
    // Re-applied to Site B's embedded `PlaceDetailModal` below — no longer
    // strictly required now that it's plain view embedding rather than a
    // `.sheet` boundary (environment propagates normally through the
    // hierarchy), but left explicit rather than relying on that: cheap
    // insurance against a repeat of the T-033/PAS-13 environment-propagation
    // crash this file's history already paid for once.
    @Environment(SavedPlacesStore.self) private var savedPlacesStore
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
                .onTapGesture { router.closeHood() }

            card
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > Self.dismissDragThreshold {
                                router.closeHood()
                            }
                        }
                )

            // Site B (TRD §4.2): layered directly above this view's own
            // card, not a `.sheet` — see this type's doc comment.
            // `PlaceDetailModal` supplies its own scrim/card/drag-dismiss,
            // so no additional wrapping is needed here.
            if let place = router.place {
                PlaceDetailModal(place: place, hoods: hoods)
                    .environment(router)
                    .environment(savedPlacesStore)
                    .environment(routePreviewModel)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
    }

    private var card: some View {
        VStack(spacing: 0) {
            dragHandle
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    flagLine

                    content
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Capped like `PlacesListOverlay`'s own scrollable content (same
            // 480pt ceiling, `PAS-48`) rather than left to grow with however
            // many places a Hood has — this card is now intrinsically
            // sized, not detent-driven, so an uncapped list would make
            // short Hoods and long Hoods produce very differently sized
            // cards.
            // `.fixedSize` makes the frame clamp an *ideal* height instead of
            // inflating a *proposed* one, so short content shrinks to fit
            // instead of always claiming the full 480pt (PAS-77).
            .frame(maxHeight: 480)
            .fixedSize(horizontal: false, vertical: true)
        }
        // T-106/`PAS-106`, Aviran-direct: Liquid Glass, not opaque
        // `Color("Surface")`. Reverses `PAS-27`/T-036's own `.thickMaterial`
        // → opaque fix (translucent-over-map made text unreadable) —
        // deliberately, not rediscovered. **Nested-glass note:** when Site
        // B (`PlaceDetailModal`, below) is open over this card, its own
        // full-screen scrim sits between the two glass layers — see that
        // type's doc comment. Full rationale, the contrast-test blind spot
        // this reintroduces, and the readability tradeoff Aviran accepted:
        // `ModalGlassBackground`'s doc comment
        // (`Support/ModalGlassBackground.swift`).
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
            Text(hood.name)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                // Stable hook for UI tests (T-033/PAS-13 fix pass) — proves
                // the sheet rendered *and* is showing the right Hood's
                // content, not just that it's on screen.
                .accessibilityIdentifier("hoodSheetTitle")
            Spacer()
            closeButton
        }
    }

    private var closeButton: some View {
        Button {
            router.closeHood()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))  // 32pt visual glyph
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)  // in a 44x44pt target
        }
        .accessibilityLabel("Close")
    }

    /// tourist-trap-flag TRD §8 D5, §11 C8: three states, always present —
    /// this is the surface req 4 bullet 2's "resolved on tap by the Hood
    /// sheet" requires, since nothing else in the app resolves the
    /// not-flagged/not-yet-rated distinction visually.
    private var flagLine: some View {
        let flag = TouristFlag(hood.isTouristTrap)
        return Text(FlagCopy.hoodSheetLine(flag: flag))
            .font(.subheadline)
            .foregroundStyle(flag == .flagged ? Color("Flag") : .secondary)
    }

    @ViewBuilder
    private var content: some View {
        let places = placeCatalog.places(in: hood.id)

        // `source`/places both derive from the same already-loaded catalog —
        // the empty/error distinction is read off `source`, never guessed
        // (TRD §4.8).
        if placeCatalog.source == .unavailable && places.isEmpty {
            errorBanner
        } else {
            if let blurb = placeCatalog.blurb(for: hood.id) {
                Text(blurb)
                    .font(.body)
            }
            if places.isEmpty {
                emptyState
            } else {
                placeList(places)
            }
        }
    }

    private var errorBanner: some View {
        Label("Couldn't load this Hood's details right now", systemImage: "exclamationmark.triangle")
            .font(.body)
            .foregroundStyle(.secondary)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No places curated here yet.")
                .foregroundStyle(.secondary)
            Button("Explore another Hood") {
                router.closeHood()
            }
            // Invisible padding to reach the 44pt minimum hit area without
            // inflating the visible button (design spec, ≥44pt CTA).
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func placeList(_ places: [Place]) -> some View {
        // P1 grouping-by-category is not built (design spec §5) — a flat,
        // name-ordered list, exactly what `places(in:)` already returns.
        VStack(alignment: .leading, spacing: 0) {
            ForEach(places) { place in
                Button {
                    router.openPlace(place)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: place.category.symbolName)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .foregroundStyle(.primary)
                            Text(place.category.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(place.name), \(place.category.displayName)")

                if place.id != places.last?.id {
                    Divider()
                }
            }
        }
    }
}
