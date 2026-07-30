import SwiftUI

/// Offline pill (TRD §2.1, §3.4, §5.3 "Offline with cache" state) — small,
/// non-blocking, kept out of the map's primary visual field (top corner) so it
/// never contests Von Restorff's one-special-element rule against the actual
/// heat/Hood content (design spec §3).
struct CachedDataIndicator: View {
    var body: some View {
        Label("Showing cached data", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .accessibilityElement(children: .combine)
    }
}
