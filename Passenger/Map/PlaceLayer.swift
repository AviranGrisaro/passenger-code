import MapKit
import SwiftUI

/// One place pin (TRD §4.5, D5): category glyph, ≥44pt target, VoiceOver
/// "Name, Category". `Map/` is the only layer that composes `Places/` data
/// into a map annotation — `PlaceLayer` itself knows nothing about fetching,
/// caching, or the router; it draws what it's handed and reports a tap.
///
/// **The personal-place ring** (places-been-saved TRD §4.9, §6) is `isListed`
/// — a plain `Bool`, so `PlaceLayer` learns nothing about what "saved" means
/// and there is no channel through which provenance could leak onto the map
/// (`map-rendering-spec.md` §6). Not built here: clustering
/// (`map-rendering-spec.md` §5 — no PRD, no owner).
struct PlaceLayer: MapContent {
    let place: Place
    let isListed: Bool
    /// search-quick-filters TRD §4.10, D4/D12 — `false` renders
    /// byte-identically to this layer's pre-existing output. Independent of
    /// `isListed`: a dimmed pin keeps its personal-place ring at the same
    /// reduced opacity as the rest of it, since no requirement makes the
    /// ring depend on whether a search is open.
    let isDimmed: Bool
    let action: () -> Void

    private var dimOpacity: Double { isDimmed ? 0.25 : 1 }

    var body: some MapContent {
        Annotation(place.name, coordinate: place.coordinate) {
            // A real `Button`, not a plain tappable shape (TRD §4.5) —
            // VoiceOver needs an activatable element. Both this button and
            // the map's own `SpatialTapGesture` can fire for one physical
            // tap; both call `router.openPlace` with the same place, which
            // `DetailRouter` makes a safe no-op the second time.
            Button(action: action) {
                ZStack {
                    Image(systemName: place.category.symbolName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2)
                        .background(Circle().fill(Color.accentColor))
                    if isListed {
                        ring
                    }
                }
                .opacity(dimOpacity)
            }
            .accessibilityLabel(pinLabel)
            // Stable, locale-independent hook for UI tests (T-033/PAS-13 fix
            // pass) — the label above is fine for VoiceOver but shouldn't be
            // what a test greps for.
            .accessibilityIdentifier("placePin-\(place.id)")
        }
        .annotationTitles(.hidden)
    }

    /// Dashed, not solid — the shape pairing `map-rendering-spec.md` §6's
    /// 2026-08-02 addendum specifies, so the ring reads as an added shape in
    /// grayscale, not colour alone (PRD req 7). Inset −6pt from the pin's
    /// 44pt frame, which stays unchanged: the ring draws outside it and is
    /// excluded from hit testing, so it can never grow the tap target.
    private var ring: some View {
        Circle()
            .strokeBorder(style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
            .foregroundStyle(Color.accentColor)
            .frame(width: 56, height: 56)  // 44pt frame + 2 × 6pt inset
            .allowsHitTesting(false)
    }

    /// "Name, Category" plus, when listed, the clause
    /// `map-rendering-spec.md` §7 defines: "Port Said, Eat & Drink, in your
    /// Places."
    private var pinLabel: String {
        let base = "\(place.name), \(place.category.displayName)"
        return isListed ? base + ", in your Places" : base
    }
}
