import SwiftUI
import UIKit

/// Pure — which edges carry a live capture zone right now (TRD §4.10, D9).
/// The single place this policy lives; no view re-derives it.
enum EdgeAvailability {
    static func liveEdges(
        idiom: UIUserInterfaceIdiom,
        isPortrait: Bool,
        isAnySurfacePresented: Bool,
        isAnySheetPresented: Bool
    ) -> Set<HorizontalEdge> {
        // Any presented nav surface or system sheet removes the zone from
        // the hierarchy entirely (Q6, §2.4) — checked first since it
        // overrides idiom/orientation regardless of which.
        guard !isAnySurfacePresented, !isAnySheetPresented else { return [] }

        switch idiom {
        case .phone:
            // D9: landscape puts the capture zone under the sensor housing,
            // voiding Q7's "cannot overshoot past the bezel" argument — the
            // button path (req 6) still reaches every hour.
            return isPortrait ? [.leading, .trailing] : []
        case .pad:
            // Right edge is system Slide Over, permanently excluded (Q2) —
            // regardless of orientation.
            return [.leading]
        default:
            // No other idiom (mac, tv, carPlay, vision, unspecified) is a
            // shipping target for this feature; never live on any of them.
            return []
        }
    }
}
