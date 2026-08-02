import MapKit
import SwiftUI

/// One live-event marker (TRD §4.5, D2, D5, D7). Built as a near-copy of the
/// shipped `PlaceLayer`: an `Annotation` holding a real `Button` (VoiceOver
/// needs an activatable element), reporting a tap by calling `action`
/// directly — the same idempotent two-path pattern `PlaceLayer` already
/// ships, since `MapScreen`'s own `SpatialTapGesture` can fire for the same
/// physical tap via `EventHitTester`, and `DetailRouter.openEvent` is
/// idempotent, so both paths landing is safe.
///
/// Emits `Annotation` only — no `MapPolygon`, no area `foregroundStyle` — so
/// this layer structurally cannot compete with heat's area channel (§2.3,
/// req 2 bullet 1). Not built here: clustering (`T-041`, unowned, §8 D4).
struct EventLayer: MapContent {
    let event: LiveEvent
    let action: () -> Void

    var body: some MapContent {
        Annotation(event.name, coordinate: event.coordinate) {
            // A rounded rectangle, not `PlaceLayer`'s `Circle` — the
            // container's silhouette carries the place/event distinction so
            // it survives greyscale (req 1 bullet 4), rather than colour
            // alone. `sparkles` is [ASSUMPTION] §8 D5 — category-agnostic,
            // overturned in a line at the post-ship designer pass.
            Button(action: action) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color("EventMarker"))
                    )
            }
            .accessibilityLabel("\(event.name), event, \(event.timeLabel)")
            // Stable, locale-independent hook for UI tests, same reason
            // `PlaceLayer`'s `placePin-` identifier exists — events render at
            // every zoom (D2), so this is reachable directly, with no
            // zoomed-in launch argument needed the way place-pin UI tests do.
            .accessibilityIdentifier("eventMarker-\(event.id)")
        }
        .annotationTitles(.hidden)
    }
}
