import SwiftUI

/// The depth-1-or-2 place destination (TRD §4.8, §4.2). Nothing else in this
/// modal navigates anywhere (PRD req 3) — no closed-place badge, no
/// provenance word, no Places-list row; all T-036's.
struct PlaceDetailModal: View {
    let place: Place

    @Environment(SavedPlacesStore.self) private var savedPlaces
    @Environment(DetailRouter.self) private var router
    @Environment(\.directionsService) private var directionsService

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            categoryRow
            touristTrapSlot
            Spacer(minLength: 0)
            routeButton
        }
        .padding()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
