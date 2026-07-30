import SwiftUI

/// "Tel Aviv, right now" cold-open title (TRD §5.1). Plays on every launch, not
/// just first-ever-launch (design spec §1) — hidden → visible → fadingOut →
/// done, timed to land at ≈3.2s (fade complete) under standard motion, matching
/// the approved mockup.
///
/// **§8 D1's opaque-background extension applies here too**, not just
/// `SettingsHint`: a contrast claim against a live, unknown map background
/// isn't verifiable any other way. This is a real, deliberate deviation from
/// the approved mockup, which renders this title as bare text over the map
/// with only a `text-shadow` glow — `ios-code-reviewer` flagged the deviation
/// at `trd-review` as unacknowledged; `architect`/`product` ratified it in the
/// same pass (BOARD.md T-031, TRD §8 D1 amendment) rather than looping back
/// through a full design-approval cycle. Built to the TRD's requirement, not
/// the mockup's literal rendering.
struct ColdOpenTitle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called exactly once, when the fade-out completes — the event
    /// `PermissionPrompt` waits on (TRD §5.2), never a raw timer.
    let onFadeComplete: () -> Void

    private enum Phase {
        case hidden, visible, fadingOut, done
    }
    @State private var phase: Phase = .hidden

    var body: some View {
        Group {
            if phase == .visible || phase == .fadingOut {
                Text("Tel Aviv, right now")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("Surface"), in: Capsule())
                    .transition(.opacity)
            }
        }
        .task { await runSequence() }
    }

    private func runSequence() async {
        // Standard motion: visible at 120ms, holds until 1.0s, fades out over
        // 2.2s, done at ~3.2s — matches TRD §5.1's flow and §5.2's "≈3.4s
        // after the map's first frame" (+200ms is `PermissionPrompt`'s own
        // delay, added after `onFadeComplete` fires here).
        let appearDelay: Duration = reduceMotion ? .milliseconds(20) : .milliseconds(120)
        let holdUntilFadeOut: Duration = reduceMotion ? .milliseconds(40) : .milliseconds(880)
        let fadeOutDuration: Duration = reduceMotion ? .milliseconds(60) : .milliseconds(2200)

        try? await Task.sleep(for: appearDelay)
        withAnimation(reduceMotion ? .linear(duration: 0.05) : .easeIn(duration: 0.3)) {
            phase = .visible
        }

        try? await Task.sleep(for: holdUntilFadeOut)
        withAnimation(reduceMotion ? .linear(duration: 0.05) : .easeOut(duration: fadeOutDuration.seconds)) {
            phase = .fadingOut
        }

        try? await Task.sleep(for: fadeOutDuration)
        phase = .done
        onFadeComplete()
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
