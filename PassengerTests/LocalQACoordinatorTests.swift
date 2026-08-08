import Foundation
import Testing
@testable import Passenger

private actor NoopLocalQAPersistence: LocalQAPersisting {
    func save(_ file: LocalQAFile, generation: Int) async {}
    func loadIfPresent() async -> LocalQAFile? { nil }
}

/// A single-event source the test triggers manually, rather than
/// `DebugVisitSource`'s launch-argument/timer construction — keeps these
/// tests deterministic and fast.
private struct ManualVisitSource: VisitSource {
    let events: AsyncStream<VisitEvent>
    let continuation: AsyncStream<VisitEvent>.Continuation

    init() {
        var continuation: AsyncStream<VisitEvent>.Continuation!
        events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }
}

private struct NoopLocalQASync: LocalQASyncing {
    let state: SyncState = .disabled
    func flush(_ records: [LocalQARecord], installID: LocalQAInstallIdentity) async -> Int { 0 }
}

/// tourist-trap-flag TRD §9 row 8 (the fast, deterministic sub-checks — the
/// 5s/1.6s timing sub-checks are covered end-to-end by `PassengerUITests`'
/// C14 suite instead, matching this codebase's existing precedent of not
/// unit-testing `Task.sleep`-based dismiss timers).
@Suite("LocalQACoordinator")
@MainActor
struct LocalQACoordinatorTests {
    private static func makeCoordinator(
        answeredPlaceIDs: Set<Place.ID> = [],
        notificationAuthorization: @escaping () -> NotificationAuthorization = { .notDetermined }
    ) -> (LocalQACoordinator, ManualVisitSource) {
        let source = ManualVisitSource()
        let answerStore = LocalQAAnswerStore(persistence: NoopLocalQAPersistence())
        for id in answeredPlaceIDs {
            answerStore.record(placeID: id, answer: true, at: Date())
        }
        let coordinator = LocalQACoordinator(
            answerStore: answerStore,
            visitSource: source,
            sync: NoopLocalQASync(),
            notificationAuthorization: notificationAuthorization
        )
        return (coordinator, source)
    }

    @Test("no pending ask at start")
    func startsWithNoPendingAsk() {
        let (coordinator, _) = Self.makeCoordinator()
        #expect(coordinator.toastState == nil)
    }

    /// Suspends until `coordinator.toastState` satisfies `predicate`, by
    /// repeatedly yielding the MainActor executor rather than sleeping a
    /// fixed window (PAS-62). `coordinator.start()`'s `for await` loop and
    /// this test both run as MainActor tasks, so the event this test yields
    /// into `source` only becomes visible in `toastState` once the
    /// scheduler actually gives that loop a turn — a single hardcoded sleep
    /// is a guess at how long that takes, and under machine load the guess
    /// can be wrong. Yielding in a loop isn't a guess: it keeps handing the
    /// executor a chance to run the coordinator's pending work and returns
    /// the instant the real state change is observed, however many turns
    /// that took. `timeout` is a safety net for a genuine hang, not the
    /// synchronization mechanism — it should essentially never be hit.
    @MainActor
    private static func waitForToastState(
        on coordinator: LocalQACoordinator,
        until predicate: (LocalQACoordinator.ToastState?) -> Bool,
        timeout: Duration = .seconds(5)
    ) async {
        let deadline = ContinuousClock.now + timeout
        while !predicate(coordinator.toastState) {
            guard ContinuousClock.now < deadline else { return }
            await Task.yield()
        }
    }

    @Test("an offer-eligible event sets toastState to .asking")
    func offerEligibleEventAsks() async {
        let (coordinator, source) = Self.makeCoordinator()
        let event = VisitEvent(placeID: "p1", occurredAt: Date(), trigger: .debug)

        let task = Task { await coordinator.start() }
        source.continuation.yield(event)
        await Self.waitForToastState(on: coordinator) { $0 == .asking(event) }

        #expect(coordinator.toastState == .asking(event))
        task.cancel()
    }

    @Test("a second event while a toast is already up is dropped — one pending ask, never two")
    func secondEventWhileAskingIsDropped() async {
        let (coordinator, source) = Self.makeCoordinator()
        let first = VisitEvent(placeID: "p1", occurredAt: Date(), trigger: .debug)
        let second = VisitEvent(placeID: "p2", occurredAt: Date(), trigger: .debug)

        let task = Task { await coordinator.start() }
        source.continuation.yield(first)
        // Deterministic: wait for the real state this test asserts on.
        await Self.waitForToastState(on: coordinator) { $0 == .asking(first) }

        source.continuation.yield(second)
        // Best-effort only, disclosed rather than implied deterministic: a
        // drop (TRD §11 C11) never mutates `toastState`, so there is no
        // observable signal to wait on for "the coordinator's `for await`
        // loop actually dequeued and discarded `second`" — AsyncStream's
        // FIFO ordering guarantees `first` is fully handled before `second`
        // is even considered (both were already buffered before either was
        // processed), so the assertion below is correct and stable
        // regardless of whether this loop gives `second` a turn before it
        // runs. These yields exist only to give the guard-drop code path a
        // real chance to execute for coverage, not for correctness — unlike
        // a fixed sleep, they cost real scheduler turns rather than wall-clock
        // time, so they don't reintroduce a load-sensitive window.
        for _ in 0..<10 {
            await Task.yield()
        }

        #expect(coordinator.toastState == .asking(first))
        task.cancel()
    }

    @Test("an already-answered place never asks, even via .debug")
    func alreadyAnsweredNeverAsks() async {
        let (coordinator, source) = Self.makeCoordinator(answeredPlaceIDs: ["p1"])
        let event = VisitEvent(placeID: "p1", occurredAt: Date(), trigger: .debug)

        let task = Task { await coordinator.start() }
        source.continuation.yield(event)
        // Best-effort only, disclosed rather than implied deterministic: the
        // gate's `.suppress` branch (TRD §11 C11) never mutates `toastState`,
        // so — exactly as with the drop above — there is no observable state
        // change to poll `waitForToastState` on; a predicate for "still nil"
        // is already true before the coordinator's `for await` loop has run
        // at all, so waiting on it would prove nothing. What the assertion
        // rests on instead is that `toastState` starts `nil` and the suppress
        // path leaves it `nil` regardless of when the loop gets its turn, so
        // the expectation below is correct and stable either way. These
        // yields exist only to give the suppress code path a real chance to
        // execute for coverage, not for correctness — unlike a fixed sleep,
        // they cost real scheduler turns rather than wall-clock time, so they
        // don't reintroduce a load-sensitive window.
        for _ in 0..<10 {
            await Task.yield()
        }

        #expect(coordinator.toastState == nil)
        task.cancel()
    }

    @Test("answer(_:) immediately transitions from .asking to .confirming with the sync-state confirmation copy")
    func answerTransitionsToConfirming() async {
        let (coordinator, source) = Self.makeCoordinator()
        let event = VisitEvent(placeID: "p1", occurredAt: Date(), trigger: .debug)

        let task = Task { await coordinator.start() }
        source.continuation.yield(event)
        // Deterministic: `answer(_:)` is a no-op unless `toastState` is
        // already `.asking`, so wait for that real state rather than guessing
        // how long the coordinator's loop needs (PAS-62).
        await Self.waitForToastState(on: coordinator) { $0 == .asking(event) }

        coordinator.answer(true)
        #expect(coordinator.toastState == .confirming(text: SyncState.disabled.confirmationCopy))
        task.cancel()
    }

    @Test("answer(_:) with no pending ask is a no-op")
    func answerWithNoPendingAskIsNoop() {
        let (coordinator, _) = Self.makeCoordinator()
        coordinator.answer(true)
        #expect(coordinator.toastState == nil)
    }
}
