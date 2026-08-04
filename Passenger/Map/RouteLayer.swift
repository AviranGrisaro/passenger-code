import MapKit
import SwiftUI

/// The two route polylines — weight, dash, casing, selection dominance (TRD
/// §4.9, PRD req 1). `Map/` is the only layer that composes; this type draws
/// exactly what it's handed, the same discipline `HoodLayer`/`PlaceLayer`
/// already hold (TRD §2.2).
///
/// Line channel, not colour, carries the fast/scenic and
/// selected/unselected distinctions (`design-principles.md` §3, "never rely
/// on colour alone" — TRD §4.9): a selected route gets an 8pt casing plus a
/// 5pt line, ≥1.6x the widest Hood stroke; scenic is always dotted
/// (`dash: [2, 8]`), fast is always solid, regardless of selection.
struct RouteLayer: MapContent {
    let fast: RoutePlan?
    let scenic: RoutePlan?
    let selection: RouteKind

    var body: some MapContent {
        // Unselected drawn first (background); the selected route's casing
        // and line draw on top of it, last — selection dominance (TRD §4.9).
        if let unselectedPlan {
            MapPolyline(coordinates: unselectedPlan.coordinates)
                .stroke(Color.accentColor.opacity(0.4), style: strokeStyle(for: unselectedPlan.kind, lineWidth: 3))
        }
        if let selectedPlan {
            MapPolyline(coordinates: selectedPlan.coordinates)
                .stroke(Color(.systemBackground), lineWidth: 8)
            MapPolyline(coordinates: selectedPlan.coordinates)
                .stroke(Color.accentColor, style: strokeStyle(for: selectedPlan.kind, lineWidth: 5, roundedCap: true))
        }
    }

    private var selectedPlan: RoutePlan? {
        selection == .fast ? fast : scenic
    }

    private var unselectedPlan: RoutePlan? {
        selection == .fast ? scenic : fast
    }

    /// Scenic is always dotted, fast is always solid — independent of
    /// whether the route is currently selected (TRD §4.9's table, rows 4-5).
    private func strokeStyle(for kind: RouteKind, lineWidth: CGFloat, roundedCap: Bool = false) -> StrokeStyle {
        switch kind {
        case .fast:
            StrokeStyle(lineWidth: lineWidth, lineCap: roundedCap ? .round : .butt)
        case .scenic:
            StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [2, 8])
        }
    }
}
