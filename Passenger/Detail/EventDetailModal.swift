import SwiftUI

/// The event depth-1 destination (TRD §4.7, D6). Always depth 1 — events
/// don't participate in `placeDepth` and never nest under a Hood sheet; an
/// event replaces whatever was open (`DetailRouter.openEvent`), matching
/// `openHood`'s own swap-in-place behaviour.
///
/// Handed a `LiveEvent` by value, so this needs no new environment
/// injection beyond what's already applied at the sheet site.
///
/// **T-052/PAS-40 fix:** the original TRD §4.7 note here said this view
/// rendered `event.hoodID`'s raw slug (`kerem-hateimanim`) because adding a
/// `Hood` lookup would mean a new environment dependency. That traded a
/// user-facing bug for an implementation-cleanliness concern that doesn't
/// actually require the trade: `hoodName` below is resolved by the
/// presentation site (`MapScreen`, which already holds the loaded `[Hood]`)
/// and handed in by value, the same way `HoodSheet` is handed an
/// already-resolved `Hood` rather than a slug — so this view still adds no
/// environment read. `nil` when the id doesn't resolve to a loaded Hood (a
/// valid, tolerated state — see `PlaceCatalog`'s own orphan-`hood_id`
/// handling) or is `nil` itself; the hood row is simply omitted rather than
/// falling back to the raw slug.
struct EventDetailModal: View {
    let event: LiveEvent
    let hoodName: String?

    @Environment(DetailRouter.self) private var router
    @Environment(\.directionsService) private var directionsService

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            ForEach(EventDetailRows.rows(for: event), id: \.self) { row in
                rowView(for: row)
            }
            Spacer(minLength: 0)
            routeButton
        }
        .padding()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
            // Keyed on `hoodName`, not `event.hoodID` — `EventDetailRows`
            // still adds this row whenever `hoodID != nil` (a pure read of
            // the raw field, unaffected by whether it resolves), but this
            // view renders the *resolved* display name only, and renders
            // nothing at all for an id that doesn't match a loaded Hood,
            // rather than ever falling back to the raw slug (T-052/PAS-40).
            if let hoodName {
                Label(hoodName, systemImage: "map")
                    .foregroundStyle(.secondary)
            }
        case .category:
            // T-052/PAS-40: never the raw pipeline string — `EventDetailRows.
            // displayCategory` humanizes it (that's also where it's unit
            // tested, since this view renders nothing to check).
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
