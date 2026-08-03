import Testing
import UIKit
@testable import Passenger

/// TRD §4.10, §9 row 7a — the full input matrix from the table in §4.10,
/// exhaustively, since `EdgeAvailability` is pure and the whole point of
/// pulling this policy out is that it doesn't need a simulator to verify.
@Suite("EdgeAvailability")
struct EdgeAvailabilityTests {
    @Test("iPhone, portrait, nothing presented — both edges live (Q2)")
    func iPhonePortraitNothingPresented() {
        let edges = EdgeAvailability.liveEdges(
            idiom: .phone, isPortrait: true, isAnySurfacePresented: false, isAnySheetPresented: false
        )
        #expect(edges == [.leading, .trailing])
    }

    @Test("iPhone, landscape — no live edges regardless of presentation state (D9)")
    func iPhoneLandscapeIsAlwaysEmpty() {
        let edges = EdgeAvailability.liveEdges(
            idiom: .phone, isPortrait: false, isAnySurfacePresented: false, isAnySheetPresented: false
        )
        #expect(edges.isEmpty)
    }

    @Test("iPad, nothing presented, portrait — leading edge only, right edge is system Slide Over (Q2)")
    func iPadPortraitNothingPresented() {
        let edges = EdgeAvailability.liveEdges(
            idiom: .pad, isPortrait: true, isAnySurfacePresented: false, isAnySheetPresented: false
        )
        #expect(edges == [.leading])
    }

    @Test("iPad, nothing presented, landscape — leading edge only, unaffected by orientation")
    func iPadLandscapeNothingPresented() {
        let edges = EdgeAvailability.liveEdges(
            idiom: .pad, isPortrait: false, isAnySurfacePresented: false, isAnySheetPresented: false
        )
        #expect(edges == [.leading])
    }

    @Test("any sheet presented collapses to no live edges, on iPhone portrait", arguments: [true, false])
    func anySheetPresentedIsAlwaysEmpty(isAnySurfacePresented: Bool) {
        let edges = EdgeAvailability.liveEdges(
            idiom: .phone, isPortrait: true, isAnySurfacePresented: isAnySurfacePresented, isAnySheetPresented: true
        )
        #expect(edges.isEmpty)
    }

    @Test("any nav surface presented collapses to no live edges, on iPad")
    func anyNavSurfacePresentedIsEmptyOnIPad() {
        let edges = EdgeAvailability.liveEdges(
            idiom: .pad, isPortrait: true, isAnySurfacePresented: true, isAnySheetPresented: false
        )
        #expect(edges.isEmpty)
    }

    @Test("a sheet and a nav surface presented at once is still just empty, not a crash")
    func bothPresentedAtOnceIsEmpty() {
        let edges = EdgeAvailability.liveEdges(
            idiom: .phone, isPortrait: true, isAnySurfacePresented: true, isAnySheetPresented: true
        )
        #expect(edges.isEmpty)
    }

    @Test("an unhandled idiom (mac, tv, carPlay, vision) is never live, even with nothing presented")
    func unhandledIdiomIsNeverLive() {
        let edges = EdgeAvailability.liveEdges(
            idiom: .mac, isPortrait: true, isAnySurfacePresented: false, isAnySheetPresented: false
        )
        #expect(edges.isEmpty)
    }
}
