import Foundation

/// The one pending ask (TRD §2.1, §5). Owns `LocalQAAnswerStore` — `MapScreen`
/// reaches it only transitively through this type, never directly (TRD §2.2).
/// Consumes `VisitSource.events` one at a time and decides, via
/// `LocalQAGate`, whether each one becomes a visible toast.
@MainActor
@Observable
final class LocalQACoordinator {
    /// What the toast is currently showing, if anything. `nil` means no
    /// window should exist at all (`LocalQAPresenter` reads this directly).
    enum ToastState: Equatable {
        case asking(VisitEvent)
        case confirming(text: String)
    }

    private(set) var toastState: ToastState?

    private let answerStore: LocalQAAnswerStore
    private let visitSource: any VisitSource
    private let sync: any LocalQASyncing
    private let notificationAuthorization: () -> NotificationAuthorization
    private let now: () -> Date
    private var autoDismissTask: Task<Void, Never>?
    private var confirmationDismissTask: Task<Void, Never>?

    init(
        answerStore: LocalQAAnswerStore = LocalQAAnswerStore(),
        visitSource: any VisitSource = DebugVisitSource(),
        sync: any LocalQASyncing = DisabledLocalQASync(),
        // Always `.notDetermined` in Phase 1 (TRD §6): `UserNotifications` is
        // not linked by this task at all — nothing has ever requested
        // authorization, so this is the only honest answer, not a stub
        // standing in for a real check.
        notificationAuthorization: @escaping () -> NotificationAuthorization = { .notDetermined },
        now: @escaping () -> Date = Date.init
    ) {
        self.answerStore = answerStore
        self.visitSource = visitSource
        self.sync = sync
        self.notificationAuthorization = notificationAuthorization
        self.now = now
    }

    /// Once per session, alongside the other stores' `.task` loads.
    func loadPersistedState() async {
        await answerStore.load()
    }

    /// Runs for the life of the screen (`MapScreen`'s `.task`); consumes
    /// `visitSource.events` one at a time.
    func start() async {
        for await event in visitSource.events {
            handle(event)
        }
    }

    private func handle(_ event: VisitEvent) {
        // One pending ask, never two (TRD §11 C11) — a second event arriving
        // while a toast is already up is silently dropped rather than
        // queued; the visit isn't lost from the gate's own perspective,
        // since `lastAskedAt`/`answeredPlaceIDs` are unaffected by a drop.
        guard toastState == nil else { return }

        let decision = LocalQAGate.decide(
            placeID: event.placeID,
            trigger: event.trigger,
            notificationAuthorization: notificationAuthorization(),
            answeredPlaceIDs: answerStore.answeredPlaceIDs,
            lastAskedAt: answerStore.lastAskedAt,
            now: now()
        )
        switch decision {
        case .suppress:
            // Logged at debug level only, never with a coordinate, never in
            // release logging (TRD §5) — nothing rendered, nothing recorded.
            break
        case .offer:
            answerStore.recordOffer(now: now())
            toastState = .asking(event)
            scheduleAutoDismiss()
        }
    }

    /// Ignored: auto-dismiss after 5s (C12), nothing recorded — the place is
    /// NOT added to the ledger, so a future visit may ask again. `lastAskedAt`
    /// was already written on offer, so the daily cap still applies.
    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            guard case .asking = toastState else { return }
            toastState = nil
        }
    }

    /// Yes/No. Records the answer, shows the confirmation line for ~1.6s,
    /// then dismisses (TRD §5).
    func answer(_ yes: Bool) {
        guard case .asking(let event) = toastState else { return }
        autoDismissTask?.cancel()

        answerStore.record(placeID: event.placeID, answer: yes, at: now())
        toastState = .confirming(text: sync.state.confirmationCopy)

        confirmationDismissTask?.cancel()
        confirmationDismissTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            guard case .confirming = toastState else { return }
            toastState = nil
        }
    }
}
