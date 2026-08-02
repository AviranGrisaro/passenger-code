import Foundation

/// Phase-1 launch-argument trigger (TRD §8 D7) — same construction as the
/// shipped `-uiTestZoomedIn` (`MapScreen.swift`). `-simulateLocalQAVisit
/// <place-id>` emits exactly one `VisitEvent(trigger: .debug)` shortly after
/// launch; a real launch never carries this argument, so this source is
/// silent in production. Rejected alternatives (D7): a debug shake gesture
/// (a parked Phase-3 concept, and a hidden gesture is worse than a hidden
/// argument); an in-sheet debug button (req 8 bullet 6 forbids any in-sheet
/// ask surface, even behind a flag).
struct DebugVisitSource: VisitSource {
    let events: AsyncStream<VisitEvent>

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        events = AsyncStream { continuation in
            guard let flagIndex = arguments.firstIndex(of: "-simulateLocalQAVisit"),
                  arguments.indices.contains(flagIndex + 1)
            else {
                continuation.finish()
                return
            }
            let placeID = arguments[flagIndex + 1]
            let task = Task {
                // "Shortly after launch," not instantly — gives the map and
                // its stores a moment to finish their own `.task` loads
                // first, matching how a real visit would arrive well after
                // cold open.
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                continuation.yield(VisitEvent(placeID: placeID, occurredAt: now(), trigger: .debug))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
