import SwiftUI

/// The second door to a Hood's detail sheet (TRD §1.2, §4.7, §8 D6) — PRD req
/// 1 requires it as chrome, and nothing like it existed before this feature.
/// Visual treatment is undesigned (§8 D6); this is built to the existing
/// `NearMeButton` chrome idiom: same bottom band, same materials.
struct HoodButton: View {
    let hoodName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(hoodName, systemImage: "mappin.and.ellipse")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Capsule())
        }
        .accessibilityLabel("Open \(hoodName)")
        // Stable, locale-independent hook for UI tests (T-033/PAS-13 fix
        // pass) — the label above is fine for VoiceOver but shouldn't be
        // what a test greps for.
        .accessibilityIdentifier("hoodButton")
    }
}
