import SwiftUI

/// The toast's content (TRD §4.3, §5, C12). Presented inside
/// `LocalQAPresenter`'s passthrough window — this view itself knows nothing
/// about `UIWindow` or VoiceOver-focus mechanics, only what it's handed.
struct LocalQAToast: View {
    let state: LocalQACoordinator.ToastState
    let onYes: () -> Void
    let onNo: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            switch state {
            case .asking:
                Text(FlagCopy.toastQuestion)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("localQAToastQuestion")
                // Equal-weight, ≥44pt (design-principles.md §2 Fitts's Law
                // minimum) — neither button reads as the "recommended" one.
                HStack(spacing: 12) {
                    Button(FlagCopy.toastNo, action: onNo)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("localQAToastNo")
                    Button(FlagCopy.toastYes, action: onYes)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("localQAToastYes")
                }
            case .confirming(let text):
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("localQAToastConfirmation")
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .animation(.default, value: state)
    }
}
