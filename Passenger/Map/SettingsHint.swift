import SwiftUI
import UIKit

/// Denied-state inline copy (TRD §8 D1). `MapScreen` owns the show/auto-dismiss
/// timing; this view is the static presentation.
struct SettingsHint: View {
    var body: some View {
        Text("Location is off. Turn it on in \(settingsLink) to use Near Me.")
        .font(.footnote)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // Opaque surface-token background, not the map itself — a contrast
        // ratio against a map is unverifiable (§8 D1). Not `.ultraThinMaterial`:
        // its effective luminance varies with whatever the map draws underneath.
        .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: openSettings)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens Settings")
    }

    private var settingsLink: Text {
        Text("Settings")
            // Semantic asset color, light/dark variants — never a mockup hex
            // (TRD §8 D1). Underlined too, so the affordance survives
            // never-color-alone (design-principles.md §3) regardless of
            // whether the token itself is ever wrong.
            .foregroundStyle(Color("LinkOnSurface"))
            .underline()
    }

    private func openSettings() {
        // Deep link only — never re-invokes the system permission dialog,
        // which iOS would ignore anyway (TRD §8 D1).
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
