import SwiftUI

/// One live edge's touch position, clamped to `band` — drives the track and
/// the floating readout chip (TRD §4.8).
struct EdgeDragState: Equatable {
    let edge: HorizontalEdge
    let y: CGFloat
    let hour: Int
}

/// The 24pt capture overlay + its `DragGesture` (TRD §4.8, D7). A sibling
/// view drawn above `Map`, never a `UIGestureRecognizer`/
/// `UIViewRepresentable`/`.simultaneousGesture`/`.highPriorityGesture` — the
/// full reasoning for why this construction needs no gesture arbitration
/// against MapKit's pan recognizer lives in TRD §2.4/§4.8, not here.
///
/// **This view only exists in the hierarchy on a live edge with nothing
/// presented** — `MapScreen` inserts it conditionally from
/// `EdgeAvailability.liveEdges(...)`, never as an `isEnabled`/opacity flag
/// (D7 rule c, §4.10). That is what makes "never claim a touch while a
/// sheet is presented" structural rather than a runtime check this view
/// would otherwise need to perform on every gesture callback.
struct EdgeHourZone: View {
    let edge: HorizontalEdge
    let band: ClosedRange<CGFloat>
    @Binding var selectedHour: Int
    @Binding var activeDrag: EdgeDragState?
    /// Re-anchors "now" the moment a touch starts (TRD §4.5 item 2, §5's
    /// flow: "touch down inside the 24pt zone → `refreshIfHourRolled()`").
    /// Not in the TRD's own abbreviated `EdgeHourZone` sketch (§4.8), which
    /// lists only the four stored properties above — added because without
    /// it there is no way to satisfy §5's own flow requirement from inside
    /// this view. Fires once per drag, at the earliest point SwiftUI's
    /// `DragGesture(minimumDistance: 4)` can observe a touch at all — a few
    /// points short of the literal moment a finger lands, which no SwiftUI
    /// gesture can report without abandoning the `minimumDistance: 4`
    /// construction §4.8 requires.
    var onTouchDown: () -> Void = {}

    /// Rule (b): latched once, on the drag's first observable movement,
    /// and held for the whole drag. `nil` before that point.
    @GestureState private var isVerticalDominant: Bool?
    @State private var hasCalledTouchDownForCurrentDrag = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: EdgeGeometry.captureWidth)
            // Default `.local` coordinate space (§4.8, corrected at v3) —
            // this view's own bounds, matching `band`'s own coordinate
            // space exactly, so no shared named space is ever needed.
            .gesture(dragGesture)
            // P1 haptic (§4.11): fires on every hour crossing this view's
            // own drag produces. `HourSlider` carries the identical
            // one-liner for its own path — together this is what makes
            // "fires on every hour crossing from either path" true, since
            // this view doesn't exist in the hierarchy while the modal
            // (and therefore the slider) is open, and vice versa.
            .sensoryFeedback(.selection, trigger: selectedHour)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($isVerticalDominant) { value, state, _ in
                // Rule (b): latch on the first update this closure sees —
                // `minimumDistance: 4` guarantees that update already
                // satisfies "hypot(dx,dy) ≥ 4" (TRD §4.8).
                if state == nil {
                    state = abs(value.translation.height) > abs(value.translation.width)
                }
            }
            .onChanged { value in
                if !hasCalledTouchDownForCurrentDrag {
                    hasCalledTouchDownForCurrentDrag = true
                    onTouchDown()
                }

                // Rule (b)'s "inert for its lifetime": a horizontal-dominant
                // drag never writes an hour and never shows a track — no
                // false hour change, ever, for the rest of this gesture.
                guard isVerticalDominant == true else { return }

                let y = min(band.upperBound, max(band.lowerBound, value.location.y))
                let newHour = EdgeGeometry.hour(atY: y, in: band)
                if newHour != selectedHour {
                    // "On a real change, from either writer" (Support/HeatRepaintSignpost.swift) —
                    // never on every gesture update, only when the resolved
                    // hour actually differs from the current one.
                    HeatRepaintSignpost.begin()
                    selectedHour = newHour
                }
                activeDrag = EdgeDragState(edge: edge, y: y, hour: newHour)
            }
            .onEnded { _ in
                // "Clear activeDrag, leave selectedHour where it landed,
                // restore the hint. No commit gesture, per req 7."
                activeDrag = nil
                hasCalledTouchDownForCurrentDrag = false
            }
    }
}
