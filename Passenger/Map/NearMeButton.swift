import CoreLocation
import SwiftUI

/// Recenter control (TRD §2.1). Disabled visual state when permission is
/// denied/restricted; the authorization-driven switch (§8 D2) lives in
/// `MapScreen` — this view only renders and reports a tap.
struct NearMeButton: View {
    let authorizationStatus: CLAuthorizationStatus
    let action: () -> Void

    private var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isDenied ? "location.slash.fill" : "location.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isDenied ? Color.gray : Color.green)
                .frame(width: 52, height: 52)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().strokeBorder((isDenied ? Color.gray : Color.green).opacity(0.9), lineWidth: 1.5))
        }
        .accessibilityLabel(isDenied ? "Near me, location off" : "Near me")
    }
}
