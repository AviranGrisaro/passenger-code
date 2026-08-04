import CoreLocation
import SwiftUI

/// The two route controls — durations, the disabled line, the disclosure
/// line (TRD §4.10, §4.8, PRD reqs 3/4/5/6/7). Reads `RoutePreviewModel` and
/// writes only the selection (TRD §2.2) — it never resolves.
struct RouteControls: View {
    let model: RoutePreviewModel

    var body: some View {
        switch model.preview {
        case .idle, .noOrigin, .failed:
            // Not rendered — the plain Directions button of T-033 stands in
            // its place (TRD §4.10). `PlaceDetailModal` decides when to show
            // that fallback; this view contributes nothing in these states.
            EmptyView()
        case .resolving:
            resolvingRow
        case .resolved(let fast, let scenic):
            VStack(alignment: .leading, spacing: 8) {
                resolvedRow(fast: fast, scenic: scenic)
                disclosureLine
            }
        }
    }

    private var resolvingRow: some View {
        HStack(spacing: 8) {
            RouteControlButton(title: "Fast", isSelected: false, isEnabled: false, subtitle: nil, isLoading: true) {}
            RouteControlButton(title: "Scenic", isSelected: false, isEnabled: false, subtitle: nil, isLoading: true) {}
        }
        .accessibilityElement(children: .contain)
    }

    private func resolvedRow(fast: RoutePlan, scenic: Result<RoutePlan, ScenicUnavailable>) -> some View {
        HStack(spacing: 8) {
            RouteControlButton(
                title: "Fast", isSelected: model.selection == .fast, isEnabled: true,
                subtitle: subtitle(for: fast), isLoading: false
            ) {
                model.select(.fast)
            }
            .accessibilityIdentifier("fastRouteControl")

            switch scenic {
            case .success(let plan):
                RouteControlButton(
                    title: "Scenic", isSelected: model.selection == .scenic, isEnabled: true,
                    subtitle: subtitle(for: plan), isLoading: false
                ) {
                    model.select(.scenic)
                }
                .accessibilityIdentifier("scenicRouteControl")
            case .failure(let reason):
                // Disabled, with a plain explanatory line in the same slot
                // (TRD §4.10) — never hidden, so its rendered frame is
                // non-empty and a UI test can tell disabled from absent.
                RouteControlButton(
                    title: "Scenic", isSelected: false, isEnabled: false,
                    subtitle: Self.disabledCopy(for: reason), isLoading: false
                ) {}
                .accessibilityIdentifier("scenicRouteControl")
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// PRD req 5: rendered before the tap, whenever Scenic is the current
    /// selection — never an alert after Go (TRD §4.8). Selection can only
    /// ever reach `.scenic` through a tap on an *enabled* Scenic control, so
    /// this is never shown for a route that failed to resolve.
    @ViewBuilder
    private var disclosureLine: some View {
        if model.selection == .scenic {
            Text(DirectionsService.waypointDisclosure)
                .font(.caption)
                .foregroundStyle(.secondary)
                // §9 row 15c/A3: nothing in this feature truncates at AX5 —
                // this line wraps and grows instead.
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("scenicWaypointDisclosure")
        }
    }

    private func subtitle(for plan: RoutePlan) -> String {
        RouteControlsCopy.subtitle(for: plan)
    }

    private static func disabledCopy(for reason: ScenicUnavailable) -> String {
        RouteControlsCopy.disabledText(for: reason)
    }
}

/// The text side of `RouteControls`, pulled out as pure functions so it's
/// unit-testable without a view host — same discipline `FlagCopy` already
/// holds for the tourist-trap flag's copy (TRD §4.10).
enum RouteControlsCopy {
    /// One line per `ScenicUnavailable` case (TRD §4.10) — the enum keeps
    /// the last four apart even though they collapse to the same copy, so
    /// tests can tell which fired.
    static func disabledText(for reason: ScenicUnavailable) -> String {
        switch reason {
        case .originAndDestinationShareAHood:
            "You're already in this neighborhood."
        case .walkTooShort:
            "Too short for a scenic detour."
        case .noQualifyingHood, .notDistinct, .detourTooLong, .routingFailed:
            "No scenic alternative for this walk."
        }
    }

    static func subtitle(for plan: RoutePlan) -> String {
        let duration = durationText(plan.travelTime)
        let distance = distanceText(plan.distance)
        if let viaHoodName = plan.viaHoodName {
            return "\(duration) · \(distance) · via \(viaHoodName)"
        }
        return "\(duration) · \(distance)"
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        return "\(minutes) min"
    }

    static func distanceText(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }
}

/// One control: title, optional subtitle (duration/distance or a disabled
/// explanation), a loading state, and a 44pt-minimum tap target (HIG).
private struct RouteControlButton: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let subtitle: String?
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        // §9 row 15c/A3: the duration/distance/`via <Hood>`
                        // text must wrap or grow at AX5, never truncate —
                        // `.lineLimit` alone doesn't prevent that (T-038 §9
                        // row 8(c-ii)'s finding), `.fixedSize` does.
                        .fixedSize(horizontal: false, vertical: true)
                    if isLoading {
                        ProgressView()
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? Color.accentColor : Color.secondary)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = title
        if let subtitle { label += ", \(subtitle)" }
        if isSelected { label += ", selected" }
        return label
    }
}
