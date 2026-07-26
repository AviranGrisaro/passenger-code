import Testing
import MapKit
@testable import Passenger

struct RootMapViewTests {
    @Test("Tel Aviv region is centered on the city, not the default 0,0")
    func telAvivRegionIsCentered() {
        let region = MKCoordinateRegion.telAviv
        #expect(abs(region.center.latitude - 32.0783) < 0.001)
        #expect(abs(region.center.longitude - 34.7806) < 0.001)
    }
}
