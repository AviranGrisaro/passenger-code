import SwiftUI

/// The button-path control (TRD §4.3, §4.4, D5). Native `Slider` — never
/// custom — so the discrete VoiceOver adjustable action (swipe up/down,
/// value spoken) comes for free from `step: 1` and is not reimplemented.
struct HourSlider: View {
    @Binding var selectedHour: Int    // 0...12
    let readout: HourFormat.Readout

    var body: some View {
        Slider(
            value: Binding(
                get: { Double(selectedHour) },
                set: { newValue in
                    let rounded = Int(newValue.rounded())
                    // "On a real change, from either writer" — never on
                    // every drag tick, only when the resolved hour differs.
                    if rounded != selectedHour {
                        HeatRepaintSignpost.begin()
                    }
                    selectedHour = rounded
                }
            ),
            in: 0...12, step: 1
        )
        // Fitts's Law minimum on the control itself (design-principles.md
        // §2) regardless of how slim the drawn track is — the visible thumb
        // may render smaller than this.
        .frame(minHeight: 44)
        .tint(Color("SliderFill"))
        .overlay(alignment: .center) { tickOverlay }
        .accessibilityLabel("Map hour")
        .accessibilityValue(HourFormat.voiceOverValue(readout))
        // Not cosmetic — §9 drives this control through
        // `XCUIElement.adjust(toNormalizedSliderPosition:)`.
        .accessibilityIdentifier("hourSlider")
        // P1 haptic (§4.11) — `EdgeHourZone` carries the identical
        // one-liner for its own path; together these are what makes "fires
        // on every hour crossing from either path" true, since the two
        // views are never both in the hierarchy at once (D7 rule c).
        .sensoryFeedback(.selection, trigger: selectedHour)
    }

    /// Decorative only — drawn above the native track but never hit-tested,
    /// so it can never intercept the drag or the VoiceOver adjustable
    /// action (§4.4).
    private var tickOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ForEach(1...12, id: \.self) { hour in
                    Rectangle()
                        .fill(.secondary.opacity(0.25))
                        .frame(width: 1, height: 6)
                        .offset(x: xPosition(for: hour, width: geometry.size.width) - 0.5)
                }
                // The "now" mark, offset 0 — differs from an ordinary stop
                // in **shape** (a diamond, not a hairline), never by colour
                // alone (§9 row 5).
                Image(systemName: "diamond.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(Color("NowTick"))
                    .offset(x: xPosition(for: 0, width: geometry.size.width) - 3)
            }
        }
        .allowsHitTesting(false)
    }

    private func xPosition(for hour: Int, width: CGFloat) -> CGFloat {
        width * CGFloat(hour) / 12
    }
}
