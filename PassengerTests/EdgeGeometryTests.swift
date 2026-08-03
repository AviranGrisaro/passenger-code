import Testing
import SwiftUI
@testable import Passenger

/// TRD §4.9, §9 row 1. Pure geometry — no simulator, no gesture.
@Suite("EdgeGeometry")
struct EdgeGeometryTests {
    private static let referenceSize = CGSize(width: 393, height: 812)
    private static let referenceSafeArea = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)

    // MARK: - band(in:safeArea:) — D8

    @Test("on the 812pt reference device, the band is exactly 64...772 (708pt)")
    func referenceDeviceBandMatchesDesign() {
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: Self.referenceSafeArea)
        #expect(band.lowerBound == 64)
        #expect(band.upperBound == 772)
        #expect(band.upperBound - band.lowerBound == 708)
    }

    @Test("a smaller safe-area inset (e.g. iPhone SE) still floors to the design's numbers")
    func smallerInsetHoldsToTheFloor() {
        let smallInsetSafeArea = EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
        let band = EdgeGeometry.band(in: CGSize(width: 375, height: 667), safeArea: smallInsetSafeArea)
        #expect(band.lowerBound == 64)  // max(64, 20+5) == 64
        #expect(band.upperBound == 627) // 667 - max(40, 0+6) == 667 - 40
    }

    @Test("a larger future safe-area inset grows the band automatically, not silently wrong")
    func largerInsetGrowsTheBand() {
        let largeInsetSafeArea = EdgeInsets(top: 100, leading: 0, bottom: 50, trailing: 0)
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: largeInsetSafeArea)
        #expect(band.lowerBound == 105)  // max(64, 100+5)
        #expect(band.upperBound == 756) // 812 - max(40, 50+6)
    }

    @Test("a degenerate tiny size never constructs an invalid range")
    func degenerateSizeNeverTraps() {
        let band = EdgeGeometry.band(in: CGSize(width: 100, height: 50), safeArea: .init())
        #expect(band.lowerBound <= band.upperBound)
    }

    // MARK: - hour(atY:in:) — §9 row 1: exactly 13 distinct outputs, clamped, reachable from any y

    @Test("sweeping y across the band produces exactly 13 distinct hour outputs")
    func sweepProducesThirteenDistinctHours() {
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: Self.referenceSafeArea)
        var seen = Set<Int>()
        var y = band.lowerBound
        while y <= band.upperBound {
            seen.insert(EdgeGeometry.hour(atY: y, in: band))
            y += 1
        }
        #expect(seen == Set(0...12))
    }

    @Test("y above the band clamps to 12 (up is later), never 13")
    func aboveBandClampsToTwelve() {
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: Self.referenceSafeArea)
        #expect(EdgeGeometry.hour(atY: band.lowerBound - 500, in: band) == 12)
    }

    @Test("y below the band clamps to 0, never -1")
    func belowBandClampsToZero() {
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: Self.referenceSafeArea)
        #expect(EdgeGeometry.hour(atY: band.upperBound + 500, in: band) == 0)
    }

    @Test("every output over a dense sweep is an Int in 0...12")
    func everyOutputIsInRange() {
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: Self.referenceSafeArea)
        var y = band.lowerBound - 200
        while y <= band.upperBound + 200 {
            let hour = EdgeGeometry.hour(atY: y, in: band)
            #expect((0...12).contains(hour))
            y += 3.7
        }
    }

    @Test("sweeping from any start y reaches both 0 and 12 at the band's ends")
    func reachesBothEndsFromAnyStart() {
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: Self.referenceSafeArea)
        #expect(EdgeGeometry.hour(atY: band.lowerBound, in: band) == 12)
        #expect(EdgeGeometry.hour(atY: band.upperBound, in: band) == 0)
    }

    // MARK: - y(forHour:in:) — the inverse used to place the chip/track

    @Test("y(forHour:) is the inverse of hour(atY:) at every one of the 13 stops")
    func yForHourInvertsHourAtY() {
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: Self.referenceSafeArea)
        for hour in 0...12 {
            let y = EdgeGeometry.y(forHour: hour, in: band)
            #expect(EdgeGeometry.hour(atY: y, in: band) == hour)
        }
    }

    @Test("y(forHour:) clamps out-of-range hours to the band's ends rather than floating past it")
    func yForHourClampsOutOfRangeHours() {
        let band = EdgeGeometry.band(in: Self.referenceSize, safeArea: Self.referenceSafeArea)
        #expect(EdgeGeometry.y(forHour: -3, in: band) == band.upperBound)
        #expect(EdgeGeometry.y(forHour: 99, in: band) == band.lowerBound)
    }
}
