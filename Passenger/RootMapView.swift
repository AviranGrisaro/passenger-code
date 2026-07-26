import MapKit
import SwiftUI

/// The whole product lives on this map. No feed, no profile, no search bar,
/// no onboarding — the app opens straight to it.
struct RootMapView: View {
    @State private var camera: MapCameraPosition = .region(.telAviv)

    var body: some View {
        Map(position: $camera)
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea()
    }
}

extension MKCoordinateRegion {
    /// Tel Aviv is the only city at launch.
    static let telAviv = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 32.0783, longitude: 34.7806),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    )
}

#Preview {
    RootMapView()
}
