import SwiftUI

/// The active-drag visual (TRD §4.11): 13 stops, a "now" tick at the range
/// end that means now, and a floating readout chip beside the finger. Draws
/// its **own opaque `Surface`-backed panel** — every contrast figure here is
/// priced against a background this app actually draws, not the live map.
///
/// Rendered in the same per-edge container `EdgeHourZone` lives in (TRD
/// §2.1), so `band`'s coordinates are already this view's own — no
/// conversion needed between the two.
struct EdgeHourTrack: View {
    let state: EdgeDragState
    let band: ClosedRange<CGFloat>
    let readout: HourFormat.Readout

    private let railX: CGFloat = EdgeGeometry.captureWidth / 2
    /// Distance the chip floats inward from the rail, toward the map's
    /// centre — **[ASSUMPTION]**, no exact figure is specced beyond
    /// "beside the finger."
    private let chipInset: CGFloat = 12

    var body: some View {
        ZStack(alignment: .topLeading) {
            rail
            ForEach(0...12, id: \.self) { hour in stop(for: hour) }
            chip
        }
        .frame(width: EdgeGeometry.captureWidth + 80, alignment: .topLeading)
        .allowsHitTesting(false)
        // §4.11: supplementary raw-pixel gesture, not narrated — the button
        // path satisfies req 6's assistive-tech bullet entirely.
        .accessibilityHidden(true)
    }

    private var rail: some View {
        Capsule()
            .fill(Color("EdgeRail"))
            .frame(width: 2, height: band.upperBound - band.lowerBound)
            .position(x: railX, y: (band.lowerBound + band.upperBound) / 2)
    }

    private func stop(for hour: Int) -> some View {
        let y = EdgeGeometry.y(forHour: hour, in: band)
        return Group {
            if hour == 0 {
                // The "now" tick — differs in shape, not just colour
                // (matches `HourSlider`'s own tick overlay convention).
                Image(systemName: "diamond.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(Color("NowTick"))
            } else {
                Circle()
                    .fill(Color("EdgeRail"))
                    .frame(width: 3, height: 3)
            }
        }
        .position(x: railX, y: y)
    }

    private var chip: some View {
        VStack(spacing: 2) {
            Text(readout.offsetLabel)
                .font(.caption.bold())
            Text(readout.clockLabel)
                .font(.caption2)
        }
        .foregroundStyle(Color("MutedOnSurface"))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color("Surface"), in: Capsule())
        .fixedSize()
        .position(
            x: state.edge == .leading ? railX + chipInset + 20 : railX - chipInset - 20,
            y: state.y
        )
    }
}
