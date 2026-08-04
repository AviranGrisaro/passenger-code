import SwiftUI

/// Presentation site A's Hood destination (TRD §4.8, §4.2). Reads
/// `PlaceCatalog`/`DetailRouter` from the environment — no fetch, no local
/// copy of anything: `places(in:)`/`blurb(for:)` are dictionary reads against
/// already-fetched data.
struct HoodSheet: View {
    let hood: Hood
    /// scenic-walk (T-057): threaded through to Site B's nested
    /// `PlaceDetailModal` below, same reason `MapScreen` passes it at Site A
    /// — the corridor search needs every Hood's geometry, not just this one.
    let hoods: [Hood]

    @Environment(PlaceCatalog.self) private var placeCatalog
    @Environment(DetailRouter.self) private var router
    // Not read by this view's own body — held only to re-apply to Site B's
    // `.sheet` content below (see that modifier's comment for why).
    @Environment(SavedPlacesStore.self) private var savedPlacesStore
    @Environment(RoutePreviewModel.self) private var routePreviewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                flagLine

                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Site B (TRD §4.2): no `.presentationBackgroundInteraction` here —
        // deliberate. What's "behind" a depth-2 modal is this Hood sheet,
        // not the map, and it is already fully covered either way.
        //
        // `.environment()` re-applied here, not just at Site A: `.sheet`
        // content does not inherit `.environment(_:)` set on the *presenting*
        // view's modifier chain — confirmed by root-causing T-033/PAS-13's
        // crash (PROGRESS.md 2026-08-01). Each `.sheet` boundary needs its
        // own explicit re-application of whatever its content reads.
        .sheet(isPresented: router.isDepth2Presented) {
            if let place = router.place {
                PlaceDetailModal(place: place, hoods: hoods)
                    .environment(router)
                    .environment(savedPlacesStore)
                    .environment(routePreviewModel)
            }
        }
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
