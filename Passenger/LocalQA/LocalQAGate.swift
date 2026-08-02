import Foundation

/// Read-only mirror of `UNAuthorizationStatus`'s three states this task
/// needs (TRD §4.3). Declared here rather than importing `UserNotifications`
/// — that framework is not linked by this task at all (§6): the local
/// notification that would carry a real ask is the shared dwell-detector
/// task's, not this one's.
enum NotificationAuthorization: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
}

/// Pure decision function — offer or suppress, with a reason (TRD §4.3).
/// Knows nothing about persistence, presentation, or `Place` beyond its ID.
enum LocalQAGate {
    enum Suppressed: Equatable {
        case alreadyAnswered
        case notificationsDenied
        case dailyCapReached
    }

    enum Decision: Equatable {
        case offer
        case suppress(Suppressed)
    }

    /// Rolling 24h, not calendar day. **[ASSUMPTION]**, refining the PRD's
    /// own — "one per day" is unratified (`ux-flows.md` §9 Q1); a rolling
    /// window avoids a burst at local midnight and needs no timezone
    /// reasoning. One constant, trivially changed.
    static let dailyCapInterval: TimeInterval = 24 * 60 * 60

    /// Precedence, in order — the order is itself the contract, since it's
    /// what makes the suppression reason deterministic (TRD §4.3):
    /// 1. Already answered — holds for **every** trigger, including
    ///    `.debug` (req 8 bullet 4).
    /// 2. Notifications denied — never applies to `.debug` (there is no
    ///    notification in that path to have been denied), and there is no
    ///    other ask surface anywhere in the app (req 8 bullet 6).
    /// 3. Daily cap — rolling 24h from `lastAskedAt`.
    /// 4. Otherwise, offer.
    static func decide(
        placeID: Place.ID,
        trigger: VisitEvent.Trigger,
        notificationAuthorization: NotificationAuthorization,
        answeredPlaceIDs: Set<Place.ID>,
        lastAskedAt: Date?,
        now: Date
    ) -> Decision {
        if answeredPlaceIDs.contains(placeID) {
            return .suppress(.alreadyAnswered)
        }
        if trigger != .debug, notificationAuthorization == .denied {
            return .suppress(.notificationsDenied)
        }
        if let lastAskedAt, now.timeIntervalSince(lastAskedAt) < dailyCapInterval {
            return .suppress(.dailyCapReached)
        }
        return .offer
    }
}
