import Foundation

/// Schedules the location permission prompt off `ColdOpenTitle`'s fade-out
/// completion — an event, never a raw launch timer (TRD §5.2). One prompt,
/// ever, whether it fires from the scheduled path or an interrupting near-me
/// tap.
@MainActor
final class PermissionPrompt {
    private let locationStore: LocationStore
    private var timerTask: Task<Void, Never>?
    /// Set once the title has finished fading; cleared the moment the prompt
    /// actually fires (from either path) or is superseded by a direct request.
    private var isPending = false

    /// Mirrors `scenePhase`, set by `MapScreen`. A prompt that comes due while
    /// backgrounded stays pending and fires on the next `.active` transition
    /// instead of firing at a user who can't see it, or never firing at all.
    var isSceneActive = true {
        didSet { if isSceneActive { fireIfDue() } }
    }

    init(locationStore: LocationStore) {
        self.locationStore = locationStore
    }

    /// Called once by `ColdOpenTitle` when its fade-out completes. Fires 200ms
    /// later (≈3.4s after the map's first frame under standard motion — §5.2),
    /// only if the answer is still `.notDetermined`.
    func titleDidFinishFading() {
        isPending = true
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.fireIfDue()
        }
    }

    /// Near-me tapped while `.notDetermined`: cancels the pending scheduled
    /// prompt and requests immediately (§5.2, §8 D2).
    func requestImmediately() {
        timerTask?.cancel()
        timerTask = nil
        isPending = false
        locationStore.requestWhenInUseIfNeeded()
    }

    private func fireIfDue() {
        guard isPending, isSceneActive, locationStore.authorizationStatus == .notDetermined else { return }
        isPending = false
        locationStore.requestWhenInUseIfNeeded()
    }
}
