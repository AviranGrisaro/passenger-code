import MapKit
import SwiftUI

/// One Hood's polygon fill + zoom-gated name label (TRD §2.1). `Map/` is the
/// only layer that composes `Hoods/` geometry with a `Density/` band — this is
/// that composition (TRD §2.2); `HoodLayer` itself still knows nothing about
/// fetching or caching, only what it's handed.
struct HoodLayer: MapContent {
    let hood: Hood
    let band: HeatBand?
    /// Visible at Hood zoom and closer only (design spec §2) — the name label,
    /// never a density word (PRD req 7's silent-gap rule extends to text too).
    let showsName: Bool

    var body: some MapContent {
        MapPolygon(coordinates: hood.coordinates)
            .foregroundStyle(fillColor)
            .stroke(.secondary.opacity(0.35), lineWidth: 0.5)

        // One annotation per Hood, always present at every zoom — this is the
        // *only* place a Hood's density is ever stated in words, and it's
        // VoiceOver-only except for the plain name label. A sighted user never
        // sees a density word here (design spec §2's centroid-channel rule);
        // VoiceOver needs it because it can't perceive an absent fill the way
        // sighted users read "no fill" as "quiet or no data" (design spec §4, C10).
        Annotation(hood.name, coordinate: hood.centroid) {
            annotationContent
        }
        .annotationTitles(.hidden)
    }

    @ViewBuilder
    private var annotationContent: some View {
        if showsName {
            Text(hood.name)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .accessibilityLabel(voiceOverLabel)
        } else {
            // Invisible at city-wide zoom, but still a real accessibility
            // element so VoiceOver can reach every Hood regardless of zoom.
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel(voiceOverLabel)
        }
    }

    private var voiceOverLabel: String {
        guard let band else { return "\(hood.name), no data right now" }
        return "\(hood.name), \(band.spokenWord)"
    }

    /// No fill at all when there's no data — the map, not a color, carries
    /// "empty" (PRD req 7).
    private var fillColor: Color {
        guard let band else { return .clear }
        return HeatPalette.fill(for: band)
    }
}
