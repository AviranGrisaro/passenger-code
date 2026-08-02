import CoreLocation
import Foundation
import Testing
@testable import Passenger

/// Covers T-034 TRD §4.3's overlap predicate and §4.4's sort/cap — the
/// hardest logic in the feature, and the only part with no view, no
/// simulator, and no network in the loop.
@Suite("EventSelection")
struct EventSelectionTests {
    private static let anchor = ISO8601DateFormatter().date(from: "2026-08-03T10:00:00Z")!

    private static func event(
        id: String, startOffsetHours: Double, durationHours: Double,
        rank: Double = 0.5
    ) -> LiveEvent {
        LiveEvent(
            id: id, name: id,
            startAt: Self.anchor.addingTimeInterval(startOffsetHours * 3600),
            endAt: Self.anchor.addingTimeInterval((startOffsetHours + durationHours) * 3600),
            coordinate: CLLocationCoordinate2D(latitude: 32.06, longitude: 34.77),
            venueName: nil, hoodID: "florentin", category: nil, rank: rank, sourceName: nil
        )
    }

    // MARK: - Overlap (§4.3, D1)

    @Test("an event starting inside the bucket renders in that bucket")
    func startsInsideBucketRenders() {
        let event = Self.event(id: "a", startOffsetHours: 3, durationHours: 1)
        let selected = EventSelection.selected(from: [event], anchorHour: Self.anchor, offset: 3, now: Self.anchor)
        #expect(selected.map(\.id) == ["a"])
    }

    @Test("an event already running before the bucket still renders — overlap, not start-hour-only")
    func alreadyRunningEventRenders() {
        // Starts 2h before anchor, runs 5h — overlaps buckets 0..2.
        let event = Self.event(id: "a", startOffsetHours: -2, durationHours: 5)
        let selected = EventSelection.selected(from: [event], anchorHour: Self.anchor, offset: 1, now: Self.anchor)
        #expect(selected.map(\.id) == ["a"])
    }

    @Test("an event spans exactly the buckets its interval intersects, no more, no less")
    func spanningEventCoversExactBuckets() {
        // [-1h, +3h) overlaps buckets 0, 1, 2 — not 3 (endAt == bucketStart(3), not >).
        let event = Self.event(id: "a", startOffsetHours: -1, durationHours: 4)
        let coveredBuckets = (0...5).filter { offset in
            !EventSelection.selected(from: [event], anchorHour: Self.anchor, offset: offset, now: Self.anchor).isEmpty
        }
        #expect(coveredBuckets == [0, 1, 2])
    }

    @Test("an event entirely outside the 13h window never renders at any offset")
    func outsideWindowNeverRenders() {
        let event = Self.event(id: "a", startOffsetHours: 20, durationHours: 1)
        for offset in 0...12 {
            #expect(EventSelection.selected(from: [event], anchorHour: Self.anchor, offset: offset, now: Self.anchor).isEmpty)
        }
    }

    @Test("an event that has already ended never renders, even inside its own hour bucket")
    func alreadyEndedEventNeverRenders() {
        let event = Self.event(id: "a", startOffsetHours: -3, durationHours: 2)  // ended 1h before anchor
        #expect(EventSelection.selected(from: [event], anchorHour: Self.anchor, offset: 0, now: Self.anchor).isEmpty)
    }

    @Test("an event ends exactly at the current moment — treated as already stale, not still live")
    func endingExactlyNowIsStale() {
        let event = Self.event(id: "a", startOffsetHours: -1, durationHours: 1)  // endAt == anchor
        #expect(EventSelection.selected(from: [event], anchorHour: Self.anchor, offset: 0, now: Self.anchor).isEmpty)
    }

    @Test("an empty bucket returns [], a real answer not a missing one")
    func emptyBucketReturnsEmptyArray() {
        let event = Self.event(id: "a", startOffsetHours: 0, durationHours: 1)
        #expect(EventSelection.selected(from: [event], anchorHour: Self.anchor, offset: 5, now: Self.anchor).isEmpty)
    }

    @Test("an empty input array never renders anything")
    func emptyInputNeverRenders() {
        #expect(EventSelection.selected(from: [], anchorHour: Self.anchor, offset: 0, now: Self.anchor).isEmpty)
    }

    // MARK: - Sort and cap (§4.4)

    @Test("markerCap is 12 [ASSUMPTION §8 D3]")
    func markerCapIsTwelve() {
        #expect(EventSelection.markerCap == 12)
    }

    @Test("sorted by rank descending")
    func sortedByRankDescending() {
        let events = [
            Self.event(id: "low", startOffsetHours: 0, durationHours: 1, rank: 0.1),
            Self.event(id: "high", startOffsetHours: 0, durationHours: 1, rank: 0.9),
            Self.event(id: "mid", startOffsetHours: 0, durationHours: 1, rank: 0.5),
        ]
        let selected = EventSelection.selected(from: events, anchorHour: Self.anchor, offset: 0, now: Self.anchor)
        #expect(selected.map(\.id) == ["high", "mid", "low"])
    }

    @Test("a rank tie breaks by start time ascending, then by id — a total order, never a coin flip")
    func rankTieBreaksByStartThenID() {
        let sameRankLaterStart = Self.event(id: "b", startOffsetHours: 0.5, durationHours: 1, rank: 0.5)
        let sameRankEarlierStart = Self.event(id: "a", startOffsetHours: 0, durationHours: 1, rank: 0.5)
        let selected = EventSelection.selected(
            from: [sameRankLaterStart, sameRankEarlierStart], anchorHour: Self.anchor, offset: 0, now: Self.anchor
        )
        #expect(selected.map(\.id) == ["a", "b"])
    }

    @Test("truncates to exactly cap, keeping the top-ranked events")
    func truncatesToCap() {
        let events = (0..<14).map { i in
            Self.event(id: "e\(i)", startOffsetHours: 0, durationHours: 1, rank: Double(14 - i) / 14)
        }
        let selected = EventSelection.selected(from: events, anchorHour: Self.anchor, offset: 0, now: Self.anchor, cap: 12)
        #expect(selected.count == 12)
        #expect(selected.map(\.id) == (0..<12).map { "e\($0)" })
    }

    @Test("the result is order-independent of the input array's own order — shuffle-invariant")
    func shuffleInvariant() {
        let events = (0..<20).map { i in
            Self.event(id: "e\(i)", startOffsetHours: 0, durationHours: 1, rank: Double(i) / 20)
        }
        let normalOrder = EventSelection.selected(from: events, anchorHour: Self.anchor, offset: 0, now: Self.anchor)
        let shuffled = events.shuffled()
        let shuffledOrder = EventSelection.selected(from: shuffled, anchorHour: Self.anchor, offset: 0, now: Self.anchor)
        #expect(normalOrder.map(\.id) == shuffledOrder.map(\.id))
    }

    @Test("rank is read only as the sort key — never re-derived or scoped")
    func rankUsedOnlyAsSortKey() {
        // A structural spot-check, not a grep: two events with identical
        // rank but different everything else sort by the documented
        // tie-break alone, with no other field influencing order.
        let a = LiveEvent(
            id: "a", name: "Z event", startAt: Self.anchor, endAt: Self.anchor.addingTimeInterval(3600),
            coordinate: CLLocationCoordinate2D(latitude: 32.06, longitude: 34.77),
            venueName: "Z venue", hoodID: "z-hood", category: "z-category", rank: 0.5, sourceName: "z"
        )
        let b = LiveEvent(
            id: "b", name: "A event", startAt: Self.anchor, endAt: Self.anchor.addingTimeInterval(3600),
            coordinate: CLLocationCoordinate2D(latitude: 32.06, longitude: 34.77),
            venueName: "A venue", hoodID: "a-hood", category: "a-category", rank: 0.5, sourceName: "a"
        )
        let selected = EventSelection.selected(from: [a, b], anchorHour: Self.anchor, offset: 0, now: Self.anchor)
        // Same rank, same startAt — tie-break is `id` ascending: "a" < "b".
        #expect(selected.map(\.id) == ["a", "b"])
    }
}
