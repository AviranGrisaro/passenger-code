import MapKit
import SwiftUI

/// One place pin (TRD §4.5, D5): category glyph, ≥44pt target, VoiceOver
/// "Name, Category". `Map/` is the only layer that composes `Places/` data
/// into a map annotation — `PlaceLayer` itself knows nothing about fetching,
/// caching, or the router; it draws what it's handed and reports a tap.
///
/// Not built here: clustering (`map-rendering-spec.md` §5 — no PRD, no
/// owner) and the personal-place ring (T-036's, §4.4/§6 there). Both are out
/// of scope by TRD decision, not an oversight.
struct PlaceLayer: MapContent {
    let place: Place
    let action: () -> Void

    var body: some MapContent {
        Annotation(place.name, coordinate: place.coordinate) {
            // A real `Button`, not a plain tappable shape (TRD §4.5) —
            // VoiceOver needs an activatable element. Both this button and
            // the map's own `SpatialTapGesture` can fire for one physical
            // tap; both call `router.openPlace` with the same place, which
            // `DetailRouter` makes a safe no-op the second time.
            Button(action: action) {
                Image(systemName: place.category.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2)
                    .background(Circle().fill(Color.accentColor))
            }
            .accessibilityLabel("\(place.name), \(place.category.displayName)")
        }
        .annotationTitles(.hidden)
    }
}
