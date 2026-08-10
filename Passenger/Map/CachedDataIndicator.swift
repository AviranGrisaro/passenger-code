import SwiftUI

/// Offline pill (TRD §2.1, §3.4, §5.3 "Offline with cache" state) — small,
/// non-blocking, kept out of the map's primary visual field (top corner) so it
/// never contests Von Restorff's one-special-element rule against the actual
/// heat/Hood content (design spec §3). Liquid Glass capsule (T-107/
/// `PAS-107`, was `.thinMaterial`).
struct CachedDataIndicator: View {
    var body: some View {
        Label("Showing cached data", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            // `.regular`, same reasoning as `SearchButton` (T-107/
            // `PAS-107`) — sits over the live map, no dimming layer.
            // Grouped with `NearMeButton` under a shared
            // `GlassEffectContainer` at the `MapScreen` call site.
            .glassEffect(.regular, in: Capsule())
            .accessibilityElement(children: .combine)
    }
}
