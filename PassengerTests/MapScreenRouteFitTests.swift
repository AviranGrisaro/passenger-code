import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// `MapScreen.fittedRegion`/`visibleAboveSheetFraction`, TRD §4.9 + A3 —
/// pure functions over coordinate arrays and plain heights, tested directly
/// rather than through `.onChange` plumbing (same discipline
/// `MapScreenTests` already uses for `isNewGrant`). A3's whole point is that
/// the inset comes from measured heights, never a device constant, so these
/// tests exercise the fraction at several heights rather than trusting one
/// hardcoded number — the equivalent of §9 row 12's on-device AX5 re-run,
/// done here as a pure-function sweep instead.
@Suite("MapScreen.fittedRegion")
struct MapScreenRouteFitTests {
    private static let fast: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 32.05, longitude: 34.78),
        CLLocationCoordinate2D(latitude: 32.06, longitude: 34.79),
    ]
    /// A representative measured pair — roughly what `qa`'s iPhone 17
    /// `.medium`-sheet measurement (y 415–866) implies, but arrived at here
    /// as two heights fed through `visibleAboveSheetFraction`, not
    /// hardcoded as a fraction (that's the exact defect A3 exists to fix).
    private static let measuredFraction = MapScreen.visibleAboveSheetFraction(
        mapViewportHeight: 852, presentedSheetHeight: 437
    )

    @Test("no coordinates at all returns nil — never a false empty region")
    func emptyInputReturnsNil() {
        #expect(MapScreen.fittedRegion(fastCoordinates: [], scenicCoordinates: [], visibleAboveSheetFraction: Self.measuredFraction) == nil)
    }

    @Test("the fitted region contains every fast-route coordinate")
    func containsFastRouteCoordinates() throws {
        let region = try #require(
            MapScreen.fittedRegion(fastCoordinates: Self.fast, scenicCoordinates: [], visibleAboveSheetFraction: Self.measuredFraction)
        )
        for coordinate in Self.fast {
            #expect(Self.region(region, contains: coordinate))
        }
    }

    @Test("the fitted region also contains scenic-route coordinates when present")
    func containsScenicRouteCoordinates() throws {
        let scenic = [CLLocationCoordinate2D(latitude: 32.055, longitude: 34.795)]
        let region = try #require(
            MapScreen.fittedRegion(fastCoordinates: Self.fast, scenicCoordinates: scenic, visibleAboveSheetFraction: Self.measuredFraction)
        )
        #expect(Self.region(region, contains: scenic[0]))
    }

    @Test("with a measured fraction, the route sits in the top of the region, not centred — the bottom is left for the sheet")
    func routeSitsAboveCentreWhenMeasured() throws {
        let region = try #require(
            MapScreen.fittedRegion(fastCoordinates: Self.fast, scenicCoordinates: [], visibleAboveSheetFraction: Self.measuredFraction)
        )
        let routeCentroidLatitude = (Self.fast[0].latitude + Self.fast[1].latitude) / 2
        // The route's own centroid must sit north of the *region's* centre —
        // if the fit only added breathing room symmetrically, with no
        // bottom inset, the route's centroid and the region's centre would
        // coincide instead.
        #expect(routeCentroidLatitude > region.center.latitude)
    }

    @Test("a nil fraction (heights not yet measured) fits with zero inset — route centred, not shifted")
    func nilFractionCentresTheRoute() throws {
        let region = try #require(
            MapScreen.fittedRegion(fastCoordinates: Self.fast, scenicCoordinates: [], visibleAboveSheetFraction: nil)
        )
        let routeCentroidLatitude = (Self.fast[0].latitude + Self.fast[1].latitude) / 2
        // Zero inset: only the symmetric breathing-room padding applies, so
        // the route's centroid and the region's centre coincide — this is
        // what distinguishes "not yet measured" from "measured and tiny."
        #expect(abs(routeCentroidLatitude - region.center.latitude) < 0.0001)
    }

    @Test("scenic coordinates alone (no fast route) still produce a region")
    func scenicOnlyStillFits() {
        #expect(MapScreen.fittedRegion(fastCoordinates: [], scenicCoordinates: Self.fast, visibleAboveSheetFraction: Self.measuredFraction) != nil)
    }

    @Test("visibleAboveSheetFraction is nil until both heights are measured")
    func fractionRequiresBothHeights() {
        #expect(MapScreen.visibleAboveSheetFraction(mapViewportHeight: 0, presentedSheetHeight: 437) == nil)
        #expect(MapScreen.visibleAboveSheetFraction(mapViewportHeight: 852, presentedSheetHeight: 0) == nil)
        #expect(MapScreen.visibleAboveSheetFraction(mapViewportHeight: 0, presentedSheetHeight: 0) == nil)
    }

    @Test("visibleAboveSheetFraction tracks a taller sheet with a smaller visible fraction — this is the AX5 case (§9 row 12b)")
    func fractionShrinksAsSheetGrows() throws {
        let defaultSize = try #require(MapScreen.visibleAboveSheetFraction(mapViewportHeight: 852, presentedSheetHeight: 437))
        let ax5 = try #require(MapScreen.visibleAboveSheetFraction(mapViewportHeight: 852, presentedSheetHeight: 620))
        #expect(ax5 < defaultSize)
    }

    @Test("visibleAboveSheetFraction never goes negative or above 1, even for a momentarily-oversized sheet")
    func fractionIsClamped() throws {
        let oversized = try #require(MapScreen.visibleAboveSheetFraction(mapViewportHeight: 852, presentedSheetHeight: 2000))
        #expect(oversized >= 0.05)
        #expect(oversized <= 1.0)
    }

    private static func region(_ region: MKCoordinateRegion, contains coordinate: CLLocationCoordinate2D) -> Bool {
        let latRange = (region.center.latitude - region.span.latitudeDelta / 2)...(region.center.latitude + region.span.latitudeDelta / 2)
        let lonRange = (region.center.longitude - region.span.longitudeDelta / 2)...(region.center.longitude + region.span.longitudeDelta / 2)
        return latRange.contains(coordinate.latitude) && lonRange.contains(coordinate.longitude)
    }
}
