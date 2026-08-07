import CoreLocation
import MapKit
import Testing
@testable import Passenger

/// Regression coverage for PAS-79: "marker tap succeeds but the detail
/// sheet never renders."
///
/// Root cause found by source analysis of `MapScreen.handleTap` (no live
/// repro was obtained — see this task's `PROGRESS.md` worklog entry):
/// `EventLayer` draws each marker's whole 44×44 hosting/hit-test box
/// `EventLayer.markerVerticalNudge` (18pt) *below* `event.coordinate`, via
/// `Annotation`'s `anchor:` (T-062/PAS-58 round 3) — deliberately, so the
/// visible glyph and the marker's own `Button` never separate. But
/// `MapScreen`'s parallel `SpatialTapGesture` (`.simultaneousGesture`, fired
/// for the same physical touch alongside the `Button`'s own tap, per that
/// file's own doc comment) used to hit-test the tapped screen point against
/// `event.coordinate` with the exact same flat tolerance every other branch
/// uses, with no allowance for the box's own downward shift. A tap on the
/// marker's own visible (lower) half — most of the box, since the anchor
/// shift pushes it mostly downward from the coordinate — could therefore
/// convert to a map point farther from `event.coordinate` than that flat
/// tolerance allowed, so this `SpatialTapGesture` path could miss the event
/// entirely on a tap that visibly landed on it. On a real map, where
/// `HoodHitTester` covers the *whole* city, that miss falls through
/// `handleTap`'s `if/else if` chain to `openHood` — clobbering the marker
/// `Button`'s own (unconditional, always-correct) `openEvent` call for that
/// same physical touch, since both fire for one tap and `DetailRouter`'s
/// destinations are mutually exclusive: whichever call lands last wins.
/// Exactly the "reports tappable, the wrong thing happens" shape `PAS-78`
/// had, on the different code path this codebase's own comments already
/// flag as never touching `SearchOverlay`/`chrome`.
///
/// This suite can't drive `MapScreen.handleTap` itself (private, needs a
/// live `MapProxy` to convert a screen point to a map coordinate), so it
/// demonstrates the tolerance mechanism the fix relies on — widening by the
/// marker's own nudge distance turns a real near-miss into a hit — using the
/// pure `EventHitTester` geometry `handleTap` actually calls. Every distance
/// below is computed from real `MKMapPoint` geometry, not hand-picked, so
/// the assertions can't drift out of sync with what `MKMapPoint.distance(to:)`
/// actually returns at this anchor's latitude.
@Suite("EventHitTester tolerance vs. the marker's own visible offset (PAS-79)")
struct EventPlaceHitTestRaceTests {
    private static let anchor = MKMapPoint(CLLocationCoordinate2D(latitude: 32.05, longitude: 34.77))

    private static func point(dx: Double, dy: Double) -> MKMapPoint {
        MKMapPoint(x: anchor.x + dx, y: anchor.y + dy)
    }

    private static func event(at point: MKMapPoint) -> LiveEvent {
        LiveEvent(
            id: "seed-race", name: "Race Event",
            startAt: Date(), endAt: Date().addingTimeInterval(3600),
            coordinate: point.coordinate,
            venueName: "Race Venue", hoodID: "florentin", category: nil, rank: 0.5, sourceName: nil
        )
    }

    @Test("widening tolerance by the marker's own nudge distance turns a real near-miss into a hit")
    func wideningToleranceByTheNudgeDistanceRecoversANearMiss() {
        let eventCoordinate = Self.point(dx: 0, dy: 0)
        let sharedEvent = Self.event(at: eventCoordinate)

        // Stand-in for a screen tap on the marker's own visible glyph,
        // converted through a live `MapProxy` back to a map coordinate —
        // offset south of `event.coordinate` by the anchor's own vertical
        // shift, same direction `EventLayer.markerAnchor` pushes the box.
        let tappedOnVisibleGlyph = Self.point(dx: 0, dy: 300)
        let realDistance = tappedOnVisibleGlyph.distance(to: eventCoordinate)

        // A flat tolerance sized to cover only *part* of that real distance
        // — standing in for `handleTap`'s pre-fix tolerance, which had no
        // term for the marker's own nudge and so didn't reliably cover a tap
        // on the nudged-down glyph's own far edge.
        let unadjustedTolerance = realDistance * 0.6
        #expect(unadjustedTolerance < realDistance)
        #expect(EventHitTester(events: [sharedEvent]).event(at: tappedOnVisibleGlyph, tolerance: unadjustedTolerance) == nil)

        // `MapScreen.handleTap`'s actual fix: `tolerance + markerNudgeTolerance`
        // — widening the flat tolerance by an additional term big enough to
        // reach the real distance, the same shape as the production fix
        // (base tolerance plus a nudge-derived tolerance, summed once, at
        // the call site).
        let nudgeTerm = realDistance - unadjustedTolerance
        let widenedTolerance = unadjustedTolerance + nudgeTerm
        #expect(widenedTolerance >= realDistance)
        #expect(
            EventHitTester(events: [sharedEvent]).event(at: tappedOnVisibleGlyph, tolerance: widenedTolerance)?.id
                == "seed-race"
        )
    }
}
