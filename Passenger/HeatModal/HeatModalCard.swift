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

    /// `MapNavRow`'s own band, duplicated here rather than read live
    /// (`MapScreen.swift`'s `.padding(.bottom, 32)` + the 44pt button
    /// height shared by `HeatButton`/`SearchButton`/`ProfileButton`) — the
    /// same hardcoded-safe-area-math idiom every other bottom-chrome
    /// element in `MapScreen` already uses, per that file's own disclosed
    /// limitation on `edgeLayer(for:)`. If `MapNavRow`'s placement changes,
    /// this must change with it.
    private static let navRowBandHeight: CGFloat = 32 + 44

    /// TRD §2.3 z5: "anchored a fixed distance above the nav row… never
    /// `bottom: 0`." This is that fixed distance — clear breathing room
    /// between the card's bottom edge and the nav row's top edge, not a
    /// flush touch. Fixes F1 (2026-08-03 acceptance REJECT): the card
    /// previously used `.padding(.bottom, 8)`, which put its bottom edge
    /// *inside* the nav row's own 140pt band, so any card taller than
    /// 132pt grew straight through the Heat/Search buttons and truncated
    /// the "next day" flag to "…t day" at default text size.
    private static let gapAboveNavRow: CGFloat = 16

    /// Fixes F2 (2026-08-03 acceptance REJECT): with no cap anywhere in
    /// `Passenger/`, AX5 was reachable and `HourReadout`'s offset numeral
    /// wrapped mid-token ("+12"/"h" split across two lines) with the
    /// "next day" pill breaking across two lines inside its own capsule.
    /// `.accessibility3` is the chosen ceiling. **Basis, corrected
    /// 2026-08-07 (`qa`, `PAS-51` finding 2):** this is reasoned from
    /// `.dynamicTypeSize(...)`'s documented clamping behavior — a range
    /// upper bound caps the environment's `DynamicTypeSize` a view sees, so
    /// content above `.accessibility3` renders exactly as it does *at*
    /// `.accessibility3` — not confirmed by an on-device screenshot pass.
    /// No such pass is recorded anywhere in `PROGRESS.md` or its archive
    /// under T-032's F1/F2 rebuild; a prior version of this comment cited
    /// screenshot evidence at AX3/AX4/AX5 that does not exist in this
    /// repo's audit trail, and that claim has been removed rather than
    /// left standing. A genuine rendered-and-observed check at AX5 is
    /// still open — tracked as `PAS-51` finding 1 (TRD §9 row 5b's AX5
    /// half). AX3 was picked as the narrowest cap that still reads
    /// comfortably large — not pushed lower — since nothing about this row
    /// forced a tighter ceiling once F1's occlusion was fixed separately.
    /// Scoped to this card's `VStack` alone, not the whole app —
    /// `HourReadout` is a compact, glanceable status row (offset + clock +
    /// a same-day/next-day flag), not body text a user reads at length,
    /// and `HourSlider` beneath it is a native `Slider` with no text to
    /// scale. PRD req 5's rendered-legibility bullet (L-009, v9) requires
    /// unoccluded/unwrapped at "the largest **supported** size" — this cap
    /// is what makes AX3 that size for this surface, not a deviation from
    /// the requirement.
    private static let maxDynamicTypeSize: DynamicTypeSize = .accessibility3

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
        .padding(.bottom, Self.navRowBandHeight + Self.gapAboveNavRow)
        .dynamicTypeSize(...Self.maxDynamicTypeSize)
        // TRD §9 row 5b's own build note: the card needs an identifier for
        // its rendered frame to be queryable from a UI test (PAS-51 finding
        // 5 — `HeatModalCard.frame.maxY` vs. the safe-area bottom).
        .accessibilityIdentifier("heatModalCard")
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
