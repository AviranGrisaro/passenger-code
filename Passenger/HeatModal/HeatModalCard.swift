import SwiftUI

/// The z5 container (TRD §4.2, D2, D4) — a `ZStack` layer, **not**
/// `.sheet()`: the nav row must stay hit-testable while this is open, and a
/// system sheet would cover it. Owns its own scrim, mirroring
/// `PlacesListOverlay`/`PassportSurface` — both of those views' own headers
/// cite this type as the pattern they mirror, so this is that promise kept
/// rather than three independently-invented near-duplicates.
///
/// Composes rows, not a bare slider: T-034's live-events toggle lands as a
/// second row here; no toggle, no placeholder, no "always on" stub row
/// ships in this task (D4).
struct HeatModalCard: View {
    @Binding var selectedHour: Int
    let readout: HourFormat.Readout
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0

    /// Downward drag distance past which a release dismisses — same value
    /// as `PlacesListOverlay`/`PassportSurface`'s identical gesture.
    private static let dismissDragThreshold: CGFloat = 80

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            card
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > Self.dismissDragThreshold {
                                onDismiss()
                            }
                        }
                )
        }
        // Reduce Motion collapses the transition to 0 duration rather than
        // skipping the state change — the view is still inserted/removed,
        // it just doesn't animate doing so (§4.2).
        .transition(
            AnyTransition.move(edge: .bottom).combined(with: .opacity)
                .animation(.easeOut(duration: reduceMotion ? 0 : 0.25))
        )
    }

    private var card: some View {
        VStack(spacing: 0) {
            dragHandle
            header
            content
        }
        // Opaque `Surface` token, not `.ultraThinMaterial` — a contrast
        // ratio against a translucent layer over a live map is not a
        // number anyone can verify (T-031 §8 D1's reasoning).
        .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.secondary)
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .accessibilityHidden(true)
    }

    private var header: some View {
        HStack {
            Text("Map hour")
                .font(.title2.bold())
                .foregroundStyle(Color("MutedOnSurface"))
                .accessibilityAddTraits(.isHeader)
                // Stable hook for UI tests, matching the `placeDetailTitle`/
                // `hoodSheetTitle`/`passportSurfaceTitle` convention.
                .accessibilityIdentifier("heatModalCardTitle")
            Spacer()
            closeButton
        }
        .padding()
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))  // 32pt visual glyph
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)  // in a 44x44pt target
        }
        .accessibilityLabel("Close")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HourReadout(readout: readout)
            HourSlider(selectedHour: $selectedHour, readout: readout)
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
}
