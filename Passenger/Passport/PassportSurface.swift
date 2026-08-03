import SwiftUI

/// The z5 container (passport TRD §4.6) — a `ZStack` layer, **not** a
/// system sheet, same reason and construction as T-036's
/// `PlacesListOverlay` and T-032's `HeatModalCard`: a system sheet covers
/// the nav row and breaks `ux-flows.md` §2.1's direct-switch rule. Owns its
/// own scrim rather than sharing a component, mirroring `PlacesListOverlay`.
///
/// Opaque `Color("Surface")` background, not `.glassEffect()` or a
/// `Material` — this card sits directly over the live map, and
/// `design-principles.md`'s contrast-verifiability rule (the lesson behind
/// T-036's own `.thickMaterial` → `Color("Surface")` fix) rules out
/// translucent chrome over dynamic content here for the same reason.
///
/// No sticker and no Hood row is tappable in V1 (D10) — the ✕ and the drag
/// handle are the only interactive elements, so there is no path from this
/// surface into a depth-1 modal, unlike `PlacesListOverlay`.
struct PassportSurface: View {
    let stickers: [PassportSticker]
    let progress: [HoodProgress]
    let isOverallLocal: Bool
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0

    /// Downward drag distance past which a release dismisses — same value as
    /// `PlacesListOverlay`'s identical gesture.
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
        // it just doesn't animate doing so (TRD §4.6).
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
            Text("Passport")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !progress.isEmpty {
                    PassportProgressList(progress: progress, isOverallLocal: isOverallLocal)
                }
                PassportAlbum(stickers: stickers)
            }
            .padding()
        }
        .frame(maxHeight: 480)
    }
}
