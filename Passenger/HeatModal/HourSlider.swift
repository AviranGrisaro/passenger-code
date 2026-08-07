import SwiftUI
import UIKit

/// The button-path control (TRD §4.3, §4.4, D5). Native `UISlider` —
/// wrapped via `UIViewRepresentable` rather than SwiftUI's own `Slider` —
/// so the discrete VoiceOver adjustable action (swipe up/down, value
/// spoken) comes from the real control's own accessibility, not a
/// reimplementation. The wrapper exists solely to fix a confirmed SwiftUI
/// bug: `Slider().frame(minHeight: 44)` reports a 31pt accessibility
/// frame regardless of the layout frame around it (UIKit's bridging
/// ignores `.frame` for the element's `accessibilityFrame`), which fails
/// the ≥44pt Fitts's-Law requirement (TRD §9 row 6b) for VoiceOver and
/// Switch Control users on every text size. `HourUISlider` below
/// overrides `accessibilityFrame` directly — the one control point UIKit
/// exposes for exactly this class of bug — instead of hiding the native
/// element and reimplementing its accessibility from scratch.
struct HourSlider: View {
    @Binding var selectedHour: Int    // 0...12
    let readout: HourFormat.Readout

    var body: some View {
        HourUISliderRepresentable(selectedHour: $selectedHour, readout: readout)
            // Fitts's Law minimum on the control itself (design-principles.md
            // §2) regardless of how slim the drawn track is — the visible
            // thumb may render smaller than this. Growing the accessibility
            // frame (see `HourUISlider`) is what actually makes this true
            // for VoiceOver; this layout frame is what makes it true for
            // sighted/Switch Control touch targets.
            .frame(minHeight: 44)
            .overlay(alignment: .center) { tickOverlay }
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

/// Bridges `HourUISlider` into SwiftUI. `step: 1` isn't native to
/// `UISlider` (it's continuous), so both the drag-driven value and the
/// VoiceOver adjustable increment/decrement are rounded to whole hours
/// here and in `HourUISlider` respectively.
private struct HourUISliderRepresentable: UIViewRepresentable {
    @Binding var selectedHour: Int
    let readout: HourFormat.Readout

    func makeUIView(context: Context) -> HourUISlider {
        let slider = HourUISlider()
        slider.minimumValue = 0
        slider.maximumValue = 12
        slider.tintColor = UIColor(named: "SliderFill")
        slider.accessibilityIdentifier = "hourSlider"
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ uiView: HourUISlider, context: Context) {
        let rounded = Float(selectedHour)
        if uiView.value != rounded {
            uiView.setValue(rounded, animated: false)
        }
        uiView.accessibilityLabel = "Map hour"
        uiView.accessibilityValue = HourFormat.voiceOverValue(readout)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedHour: $selectedHour)
    }

    final class Coordinator: NSObject {
        let selectedHour: Binding<Int>

        init(selectedHour: Binding<Int>) {
            self.selectedHour = selectedHour
        }

        @objc @MainActor func valueChanged(_ sender: UISlider) {
            let rounded = Int(sender.value.rounded())
            if Float(rounded) != sender.value {
                sender.setValue(Float(rounded), animated: false)
            }
            // "On a real change, from either writer" — never on every drag
            // tick, only when the resolved hour differs.
            if rounded != selectedHour.wrappedValue {
                HeatRepaintSignpost.begin()
            }
            selectedHour.wrappedValue = rounded
        }
    }
}

/// A `UISlider` whose accessibility frame is at least 44pt tall (Fitts's
/// Law, TRD §9 row 6b), independent of how slim the drawn track is, and
/// whose VoiceOver adjustable action moves one hour per swipe rather than
/// `UISlider`'s default `(max - min) / 10` continuous increment.
private final class HourUISlider: UISlider {
    private static let minAccessibleHeight: CGFloat = 44

    override var accessibilityFrame: CGRect {
        get {
            let base = super.accessibilityFrame
            guard base.height < Self.minAccessibleHeight else { return base }
            let inset = (Self.minAccessibleHeight - base.height) / 2
            return base.insetBy(dx: 0, dy: -inset)
        }
        set { super.accessibilityFrame = newValue }
    }

    override func accessibilityIncrement() {
        value = min(value + 1, maximumValue)
        sendActions(for: .valueChanged)
    }

    override func accessibilityDecrement() {
        value = max(value - 1, minimumValue)
        sendActions(for: .valueChanged)
    }
}
