import SwiftUI

/// Presentation site A's Hood destination (TRD §4.8, §4.2). Reads
/// `PlaceCatalog`/`DetailRouter` from the environment — no fetch, no local
/// copy of anything: `places(in:)`/`blurb(for:)` are dictionary reads against
/// already-fetched data.
struct HoodSheet: View {
    let hood: Hood

    @Environment(PlaceCatalog.self) private var placeCatalog
    @Environment(DetailRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(hood.name)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

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
        .sheet(isPresented: router.isDepth2Presented) {
            if let place = router.place {
                PlaceDetailModal(place: place)
            }
        }
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
