import Foundation
import Testing
@testable import Passenger

/// tourist-trap-flag TRD §9 row 8a: the full input matrix (3 triggers × 3
/// auth states × answered/not × cap/not), precedence order asserted exactly
/// as §4.3 states it.
@Suite("LocalQAGate")
struct LocalQAGateTests {
    private static let placeID = "florentin-anna-loulou-bar"
    private static let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("already-answered wins over every other condition, including .debug")
    func alreadyAnsweredWinsOverEverything() {
        for trigger: VisitEvent.Trigger in [.notificationTap, .foregroundArrival, .debug] {
            for auth: NotificationAuthorization in [.notDetermined, .authorized, .denied] {
                let decision = LocalQAGate.decide(
                    placeID: Self.placeID,
                    trigger: trigger,
                    notificationAuthorization: auth,
                    answeredPlaceIDs: [Self.placeID],
                    lastAskedAt: nil,
                    now: Self.now
                )
                #expect(decision == .suppress(.alreadyAnswered))
            }
        }
    }

    @Test(".debug is never suppressed by notifications-denied — there is no notification in that path to have been denied")
    func debugTriggerIgnoresNotificationsDenied() {
        let decision = LocalQAGate.decide(
            placeID: Self.placeID,
            trigger: .debug,
            notificationAuthorization: .denied,
            answeredPlaceIDs: [],
            lastAskedAt: nil,
            now: Self.now
        )
        #expect(decision == .offer)
    }

    @Test("a real trigger IS suppressed by notifications-denied, with no fallback (req 8 bullet 6)")
    func realTriggerSuppressedByNotificationsDenied() {
        for trigger: VisitEvent.Trigger in [.notificationTap, .foregroundArrival] {
            let decision = LocalQAGate.decide(
                placeID: Self.placeID,
                trigger: trigger,
                notificationAuthorization: .denied,
                answeredPlaceIDs: [],
                lastAskedAt: nil,
                now: Self.now
            )
            #expect(decision == .suppress(.notificationsDenied))
        }
    }

    @Test("within the rolling 24h cap is suppressed")
    func withinDailyCapIsSuppressed() {
        let lastAskedAt = Self.now.addingTimeInterval(-LocalQAGate.dailyCapInterval + 1)
        let decision = LocalQAGate.decide(
            placeID: Self.placeID,
            trigger: .debug,
            notificationAuthorization: .notDetermined,
            answeredPlaceIDs: [],
            lastAskedAt: lastAskedAt,
            now: Self.now
        )
        #expect(decision == .suppress(.dailyCapReached))
    }

    @Test("exactly at the 24h boundary is no longer capped")
    func exactlyAtDailyCapBoundaryOffers() {
        let lastAskedAt = Self.now.addingTimeInterval(-LocalQAGate.dailyCapInterval)
        let decision = LocalQAGate.decide(
            placeID: Self.placeID,
            trigger: .debug,
            notificationAuthorization: .notDetermined,
            answeredPlaceIDs: [],
            lastAskedAt: lastAskedAt,
            now: Self.now
        )
        #expect(decision == .offer)
    }

    @Test("no prior ask, not answered, notifications not denied — offers")
    func cleanStateOffers() {
        for trigger: VisitEvent.Trigger in [.notificationTap, .foregroundArrival, .debug] {
            for auth: NotificationAuthorization in [.notDetermined, .authorized] {
                let decision = LocalQAGate.decide(
                    placeID: Self.placeID,
                    trigger: trigger,
                    notificationAuthorization: auth,
                    answeredPlaceIDs: [],
                    lastAskedAt: nil,
                    now: Self.now
                )
                #expect(decision == .offer)
            }
        }
    }

    @Test("the daily cap is checked against lastAskedAt, not tied to any particular place")
    func dailyCapIsGlobalNotPerPlace() {
        // A different place recently asked-about still trips the cap for
        // this one — `lastAskedAt` is one clock for the whole install
        // (TRD §8 D8), not per-place.
        let lastAskedAt = Self.now.addingTimeInterval(-60)
        let decision = LocalQAGate.decide(
            placeID: "a-totally-different-place",
            trigger: .debug,
            notificationAuthorization: .notDetermined,
            answeredPlaceIDs: [],
            lastAskedAt: lastAskedAt,
            now: Self.now
        )
        #expect(decision == .suppress(.dailyCapReached))
    }
}
