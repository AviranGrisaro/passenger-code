import SwiftUI
import UIKit

/// The passthrough `UIWindow` TRD §8 D4 requires. A `.sheet` presents in its
/// own presentation host above whatever `MapScreen` overlays, so a toast
/// drawn as a `ZStack` overlay would be hidden behind an open Hood or place
/// sheet — this window sits above everything instead, entirely outside
/// SwiftUI's own presentation hierarchy.
///
/// **Non-blocking (req 8 bullet 1) is structural, not a hit-test opt-out on
/// the toast's siblings:** `PassthroughWindow.hitTest` returns `nil` for
/// every point outside the toast's own bounds, so the rest of the screen —
/// including any sheet still open underneath — never receives this window
/// at all.
///
/// **VoiceOver-focus mechanics are build requirements here, not a review
/// note (TRD §9 row 8(f), C12):** shown via `isHidden = false`, **never
/// `makeKeyAndVisible`** — a key window pulls VoiceOver focus regardless of
/// which notification is posted below — `accessibilityViewIsModal` left
/// **false**, window level **`.normal + 1`**, and exactly one
/// `UIAccessibility.post(notification: .announcement, ...)` per toast
/// appearance (never `.screenChanged`/`.layoutChanged`).
@MainActor
final class LocalQAPresenter {
    private var window: PassthroughWindow?
    private var hostingController: UIHostingController<LocalQAToast>?

    /// Call from a SwiftUI `.onChange` on `coordinator.toastState` — the
    /// same window is reused across an ask → confirm → dismiss cycle rather
    /// than recreated for each state, so the `.announcement` post below
    /// fires exactly once per appearance, not once per state transition.
    func update(coordinator: LocalQACoordinator) {
        guard let state = coordinator.toastState else {
            teardown()
            return
        }

        let content = LocalQAToast(
            state: state,
            onYes: { [weak coordinator] in coordinator?.answer(true) },
            onNo: { [weak coordinator] in coordinator?.answer(false) }
        )

        if let hostingController {
            hostingController.rootView = content
        } else {
            present(content: content)
        }
    }

    private func present(content: LocalQAToast) {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear
        window.accessibilityViewIsModal = false

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        window.rootViewController = hosting

        // Never `makeKeyAndVisible` (D4, §9 row 8f).
        window.isHidden = false

        self.window = window
        self.hostingController = hosting

        UIAccessibility.post(notification: .announcement, argument: FlagCopy.toastQuestion)
    }

    private func teardown() {
        window?.isHidden = true
        window = nil
        hostingController = nil
    }
}

/// Returns `nil` for any point outside the toast's own rendered content, so
/// the window never intercepts a touch anywhere else on screen (D4).
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event), hit !== self else { return nil }
        return hit
    }
}
