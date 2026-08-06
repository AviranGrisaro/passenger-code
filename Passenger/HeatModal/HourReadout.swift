import SwiftUI

/// Numeral + clock time + "next day" pill (TRD §3.2, §4.12). Every text
/// label here renders in exactly one foreground token, `MutedOnSurface`, on
/// exactly one of two backgrounds — `Surface` (this view's own background,
/// applied by `HeatModalCard`) or `PillSurface` (the "next day" pill only).
struct HourReadout: View {
    let readout: HourFormat.Readout

    var body: some View {
        HStack(spacing: 8) {
            Text(readout.offsetLabel)
                .font(.title2.bold())
                .foregroundStyle(Color("MutedOnSurface"))
            Text(readout.clockLabel)
                .font(.subheadline)
                .foregroundStyle(Color("MutedOnSurface"))
            if readout.isNextDay {
                Text("next day")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color("MutedOnSurface"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color("PillSurface"), in: Capsule())
            }
        }
        // One spoken unit — "Now, 18:00" or "+3 hours, 21:00, next day" —
        // rather than three separate stops for what is one fact.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(HourFormat.voiceOverValue(readout))
        // Stable hook for UI tests, matching the `heatModalCardTitle`/
        // `hourSlider` convention — lets a rendered layout test grab this
        // row's real frame (T-032 F1 rebuild, 2026-08-03).
        .accessibilityIdentifier("hourReadout")
    }
}
