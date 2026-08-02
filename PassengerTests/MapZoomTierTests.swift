import Testing
@testable import Passenger

/// tourist-trap-flag TRD §9 row 3a: three distinct tiers, boundaries
/// exclusive/inclusive as specified, no fourth outcome.
@Suite("MapZoomTier")
struct MapZoomTierTests {
    @Test("well inside each tier resolves correctly")
    func wellInsideEachTier() {
        #expect(MapZoomTier.tier(forLatitudeDelta: 0.01) == .close)
        #expect(MapZoomTier.tier(forLatitudeDelta: 0.08) == .neighborhood)
        #expect(MapZoomTier.tier(forLatitudeDelta: 0.14) == .cityWide)
    }

    @Test("closeSpanThreshold is exclusive on the close side — exactly at it is neighborhood")
    func closeThresholdBoundary() {
        #expect(MapZoomTier.tier(forLatitudeDelta: MapZoomTier.closeSpanThreshold) == .neighborhood)
        #expect(MapZoomTier.tier(forLatitudeDelta: MapZoomTier.closeSpanThreshold - 0.0001) == .close)
    }

    @Test("neighborhoodSpanThreshold is exclusive on the neighborhood side — exactly at it is cityWide")
    func neighborhoodThresholdBoundary() {
        #expect(MapZoomTier.tier(forLatitudeDelta: MapZoomTier.neighborhoodSpanThreshold) == .cityWide)
        #expect(MapZoomTier.tier(forLatitudeDelta: MapZoomTier.neighborhoodSpanThreshold - 0.0001) == .neighborhood)
    }

    @Test("neighborhoodSpanThreshold sits strictly between closeSpanThreshold and the cold-open span (0.14)")
    func neighborhoodThresholdIsBetweenCloseAndColdOpen() {
        #expect(MapZoomTier.neighborhoodSpanThreshold > MapZoomTier.closeSpanThreshold)
        #expect(MapZoomTier.neighborhoodSpanThreshold < 0.14)
    }

    @Test("closeSpanThreshold is unchanged from the pre-flag nameLabelSpanThreshold value (0.06) — no existing behaviour moves")
    func closeThresholdUnchanged() {
        #expect(MapZoomTier.closeSpanThreshold == 0.06)
    }
}
