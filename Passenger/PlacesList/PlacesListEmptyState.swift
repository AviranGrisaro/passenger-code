import SwiftUI

/// Icon + one line + a real CTA (TRD §4.7, §9 row 6) — built from the start,
/// not after a review finding. The CTA dismisses the list, same mechanism as
/// the drag handle and ✕ (TRD §4.5).
struct PlacesListEmptyState: View {
    let onExplore: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Nothing here yet")
                .font(.headline)
            Button("Explore the map", action: onExplore)
                .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
