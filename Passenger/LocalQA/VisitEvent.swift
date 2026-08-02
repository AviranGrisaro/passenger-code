import Foundation

/// `LocalQA/` never imports `Hoods/` or `Map/` (TRD §2.2) — it knows a
/// `Place.ID` and nothing about geometry. This is the contract the future
/// geofence dwell detector must satisfy, and the only thing this task
/// requires of it; the detector itself, the Always-authorization prompt, and
/// the local notification that carries the ask are outside this task (§1).
struct VisitEvent: Sendable, Equatable {
    enum Trigger: Sendable, Equatable {
        case notificationTap
        case foregroundArrival
        case debug
    }

    let placeID: Place.ID
    let occurredAt: Date
    let trigger: Trigger
}

/// One event stream, one owner. Phase 1 ships exactly one conformer
/// (`DebugVisitSource`); Phase 2+ substitutes the real detector without any
/// other change here (TRD §7).
protocol VisitSource: Sendable {
    var events: AsyncStream<VisitEvent> { get }
}
