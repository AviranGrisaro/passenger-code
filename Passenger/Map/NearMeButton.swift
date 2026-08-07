import CoreLocation
import SwiftUI

/// Recenter control (TRD §2.1). Disabled visual state when permission is
/// denied/restricted; the authorization-driven switch (§8 D2) lives in
/// `MapScreen` — this view only renders and reports a tap.
///
/// **T-078/`PAS-60` reopened (`nav-row-v2-redesign.md` §2):** relocated out
/// of `MapNavRow` into `MapScreen`'s top-trailing overlay, alongside
/// `CachedDataIndicator` — Apple/Google-Maps-style top-right placement, per
/// Aviran's explicit instruction (overriding those apps' own bottom-right
/// convention). Restyled as a secondary utility control, not one of the 3
/// primary nav-row actions: 44×44 (the Fitts's Law floor, not inflated to
/// the row's 52×52), gray by default/denied, `Color.blue` only while
/// actively tracking — blue ties it into the new nav-row palette (§4) so it
/// reads as the same app rather than a 4th unrelated hue, while its
/// position and smaller size already differentiate it from the 3-button
/// row. No colored stroke ring (§4 — dropped for all 4 buttons).
struct NearMeButton: View {
    let authorizationStatus: CLAuthorizationStatus
    let action: () -> Void

    private var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    private var isTracking: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isDenied ? "location.slash.fill" : "location.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isTracking ? Color.blue : Color.secondary)
                .frame(width: 44, height: 44)  // Fitts's Law minimum (design-principles.md §2) — secondary control, not nav-row scale
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel(isDenied ? "Near me, location off" : "Near me")
    }
}
