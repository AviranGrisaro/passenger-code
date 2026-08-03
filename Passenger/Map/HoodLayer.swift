import MapKit
import SwiftUI

/// One Hood's polygon fill + zoom-gated name label + tourist-trap flag
/// stroke/label (TRD §2.1, tourist-trap-flag TRD §2.1, §2.3). `Map/` is the
/// only layer that composes `Hoods/` geometry with a `Density/` band and the
/// `Flag/` vocabulary — this is that composition (TRD §2.2); `HoodLayer`
/// itself still knows nothing about fetching or caching, only what it's
/// handed. It never sees `LocalQA/` — that module never reads or writes
/// `HoodCatalog` (tourist-trap-flag TRD §2.2).
struct HoodLayer: MapContent {
    let hood: Hood
    let band: HeatBand?
    /// `MapZoomTier.tier(forLatitudeDelta:)`'s result — the single derivation
    /// of zoom the whole layer reads, so the name label, the flag stroke and
    /// the flag label can never silently disagree about what tier they're in
    /// (tourist-trap-flag TRD §2.2).
    let zoomTier: MapZoomTier
    /// search-quick-filters TRD §4.10, D4 — `false` renders byte-identically
    /// to this layer's pre-existing output; `true` multiplies every visible
    /// element's opacity by 0.25. Computed by `MapScreen` from the live
    /// search result set, never stored here.
    let isDimmed: Bool

    /// Visible at `.close` only (design spec §2) — unchanged threshold and
    /// unchanged behaviour from before the flag existed (tourist-trap-flag
    /// TRD §2.3: `closeSpanThreshold` **is** the old `nameLabelSpanThreshold`,
    /// renamed in place).
    private var showsName: Bool { zoomTier == .close }

    /// The one multiplier every visible element in this layer applies
    /// (search-quick-filters TRD §4.10) — `1` is a no-op, so an undimmed
    /// Hood's rendering is untouched by this task.
    private var dimOpacity: Double { isDimmed ? 0.25 : 1 }

    private var flag: TouristFlag { TouristFlag(hood.isTouristTrap) }

    /// The stroke `FlagStroke.treatment(for:band:)` would return, forced to
    /// `.none` at `.cityWide` regardless of flag state — "no stroke at this
    /// zoom, for any zone" (`map-rendering-spec.md` §2) is a zoom rule, not a
    /// flag rule, so it's applied here rather than folded into the pure
    /// treatment function (tourist-trap-flag TRD §9 row 3).
    private var effectiveStroke: FlagStroke {
        zoomTier == .cityWide ? .none : FlagStroke.treatment(for: flag, band: band)
    }

    var body: some MapContent {
        switch effectiveStroke {
        case .none:
            MapPolygon(coordinates: hood.coordinates)
                .foregroundStyle(fillColor)
                .stroke(.secondary.opacity(0.35 * dimOpacity), lineWidth: 0.5)
        case .plain:
            MapPolygon(coordinates: hood.coordinates)
                .foregroundStyle(fillColor)
                .stroke(Color("Flag").opacity(dimOpacity), lineWidth: 2.5)
        case .busyWarning:
            MapPolygon(coordinates: hood.coordinates)
                .foregroundStyle(fillColor)
                .stroke(Color("Flag").opacity(dimOpacity), style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
        }

        // One annotation per Hood, always present at every zoom — this is the
        // *only* place a Hood's density (and, when flagged, its tourist-trap
        // status) is ever stated in words, and it's VoiceOver-only except for
        // the visible capsule text. A sighted user never sees a density word
        // here (design spec §2's centroid-channel rule); VoiceOver needs it
        // because it can't perceive an absent fill the way sighted users read
        // "no fill" as "quiet or no data" (design spec §4, C10).
        Annotation(hood.name, coordinate: hood.centroid) {
            annotationContent
        }
        .annotationTitles(.hidden)
    }

    @ViewBuilder
    private var annotationContent: some View {
        Group {
            if showsName {
                Text(hood.name)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                    .accessibilityLabel(voiceOverLabel)
            } else if zoomTier == .neighborhood, let flagLabelText = FlagCopy.centroidLabel(flag: flag, band: band) {
                // The flag's own label — `.neighborhood` tier only, flagged
                // Hoods only (tourist-trap-flag TRD §4.2, §9 row 3). Never
                // co-occurs with the plain name capsule above: that one is
                // gated to `.close`, this one to `.neighborhood`, by
                // construction.
                Text(flagLabelText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color("Flag"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                    .accessibilityLabel(voiceOverLabel)
            } else {
                // Invisible at city-wide zoom (and at neighborhood zoom for
                // an unflagged Hood), but still a real accessibility element
                // so VoiceOver can reach every Hood regardless of zoom.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(voiceOverLabel)
            }
        }
        // search-quick-filters TRD §4.10 — the whole annotation dims as one
        // unit; `dimOpacity == 1` when `isDimmed` is `false`, so this is a
        // no-op for every caller that predates this task.
        .opacity(dimOpacity)
    }

    private var voiceOverLabel: String {
        HoodSpeech.label(name: hood.name, band: band, flag: flag)
    }

    /// No fill at all when there's no data — the map, not a color, carries
    /// "empty" (PRD req 7).
    private var fillColor: Color {
        guard let band else { return .clear }
        return HeatPalette.fill(for: band)
    }
}
