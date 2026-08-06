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
    /// element's opacity by 0.25, **including the polygon's heat fill**
    /// (`fillColor`, via `HeatPalette.fillOpacity(for:dimmedBy:)`) — not
    /// only the stroke and the centroid annotation, which is all this
    /// multiplier reached before T-038/PAS-29's second acceptance pass
    /// (F1a). Computed by `MapScreen` from the live search result set, never
    /// stored here.
    let isDimmed: Bool

    /// Pointer-only (trackpad on iPad / Mac idiom, `MapScreen.handleHover`) —
    /// `MapScreen` passes `true` for the one Hood under the pointer, `false`
    /// (the default) for every other Hood and for every touch-only device,
    /// where `onContinuousHover` never fires at all.
    let isHovered: Bool

    /// Explicit rather than the synthesized memberwise init, so `isHovered`
    /// can default to `false` at the call site: every pre-existing 4-arg
    /// call site (including `HoodLayerFillDimTests`) keeps compiling
    /// unchanged, still rendering byte-identically to before this property
    /// existed.
    init(hood: Hood, band: HeatBand?, zoomTier: MapZoomTier, isDimmed: Bool, isHovered: Bool = false) {
        self.hood = hood
        self.band = band
        self.zoomTier = zoomTier
        self.isDimmed = isDimmed
        self.isHovered = isHovered
    }

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
                .foregroundStyle(.clear)
                .stroke(borderColor, lineWidth: strokeWidth(base: 0.5))
        case .plain:
            MapPolygon(coordinates: hood.coordinates)
                .foregroundStyle(.clear)
                .stroke(Color("Flag").opacity(min(dimOpacity * hoverGlow, 1)), lineWidth: strokeWidth(base: 2.5))
        case .busyWarning:
            MapPolygon(coordinates: hood.coordinates)
                .foregroundStyle(.clear)
                .stroke(
                    Color("Flag").opacity(min(dimOpacity * hoverGlow, 1)),
                    style: StrokeStyle(lineWidth: strokeWidth(base: 3), dash: [6, 4])
                )
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
    /// "empty" (PRD req 7). Dimmed by the same `dimOpacity` the stroke and
    /// annotation apply (search-quick-filters TRD §4.10, F1a fix) — a `nil`
    /// band stays `.clear` either way, since dimming a fully-transparent fill
    /// has nothing to multiply. Not `private`: `HoodLayerFillDimTests`
    /// reads this directly to assert the dim reaches the rendered alpha,
    /// not just the `isDimmed` value handed in (L-009).
    var fillColor: Color {
        guard let band else { return .clear }
        return HeatPalette.hue.opacity(HeatPalette.fillOpacity(for: band, dimmedBy: dimOpacity))
    }

    /// Design fix (2026-08-04): a Hood is marked by its border alone, never
    /// by a filled interior — `fillColor` above is kept only as a cheap
    /// regression guard on a still-computed value and no longer reaches
    /// `body`. The color that used to live in the interior fill now lives in
    /// this line instead: no band still draws the old neutral hairline, a
    /// banded Hood's line carries `HeatPalette.hue`, boosted well past
    /// `fillColor`'s own translucent-fill opacity steps (0.16/0.38/0.62)
    /// since a thin stroke at fill-strength alpha would be nearly invisible
    /// against the map. Not `private`: `HoodLayerFillDimTests` reads this
    /// directly to assert the dim reaches the channel `body` actually draws
    /// — the same trade `fillColor` already made and documented
    /// (search-quick-filters TRD §9 row 4, T-038/PAS-55, C15/D15).
    var borderColor: Color {
        guard let band else { return .secondary.opacity(min(0.35 * hoverGlow, 1) * dimOpacity) }
        let bandStrength = min(HeatPalette.opacity(for: band) + 0.35, 1)
        return HeatPalette.hue.opacity(min(bandStrength * hoverGlow, 1) * dimOpacity)
    }

    /// The "glow a little" a border gets under the pointer (design fix,
    /// 2026-08-04) — `1` (no-op) whenever `isHovered` is `false`, which is
    /// every Hood on a touch-only device, so this never changes anything
    /// there. Multiplies alongside `dimOpacity` rather than replacing it, so
    /// a hovered-but-search-dimmed Hood still reads as dimmed, just less so.
    private var hoverGlow: Double { isHovered ? 1.4 : 1.0 }

    /// A hovered border is a touch thicker as well as brighter — same
    /// `isHovered` no-op guarantee as `hoverGlow`.
    private func strokeWidth(base: CGFloat) -> CGFloat {
        base + (isHovered ? 1 : 0)
    }
}
