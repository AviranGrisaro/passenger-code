import SwiftUI

/// Icon + one line + a real CTA (TRD §4.7, §9 row 6) — built from the start,
/// not after a review finding. The CTA dismisses the list, same mechanism as
/// the drag handle and ✕ (TRD §4.5).
///
/// The line names what would fill the list (PRD req 6 bullet 1) rather than
/// only stating that it's empty. V1 has no onboarding, so this is the only
/// surface that can explain the feature to a first-run user — "Nothing here
/// yet" alone named nothing and shipped a REJECT at acceptance (2026-08-03,
/// `PAS-27`/L-009).
struct PlacesListEmptyState: View {
    let onExplore: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Save a place from its detail card, or spend enough time at one, and it'll show up here.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Explore the map", action: onExplore)
                .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
