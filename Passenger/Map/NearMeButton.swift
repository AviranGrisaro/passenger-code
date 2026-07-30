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
                .font(.title3)
                .foregroundStyle(isDenied ? .secondary : .primary)
                .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel(isDenied ? "Near me, location off" : "Near me")
    }
}
