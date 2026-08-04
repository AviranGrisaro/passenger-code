/// Why no scenic route exists. Every case is a *stated* state (PRD req 4),
/// never a silent `nil` — `RouteControls` renders one line per case (TRD
/// §3.2, §4.10).
enum ScenicUnavailable: Error, Sendable, Equatable, Hashable {
    case originAndDestinationShareAHood
    /// The fast route is under `RouteBounds.minimumFastTravelTime`.
    case walkTooShort
    /// No `false`-flagged Hood in the corridor.
    case noQualifyingHood
    /// Every candidate attempt failed `RouteBounds.accepts`.
    case detourTooLong
    /// The returned route did not diverge from fast (req 4, bullet 3).
    case notDistinct
    /// A directions-provider error on a scenic leg only — the fast route
    /// still resolved.
    case routingFailed
}

/// The whole state of one place's route resolution (TRD §3.2, §4.4). A
/// `RoutePreviewModel` holds exactly one of these at a time; there is no
/// partial or optional variant — every terminal state is named.
enum RoutePreview: Sendable, Equatable {
    case idle
    case resolving
    /// PRD req 6 — no location authorization, no polyline, no duration
    /// claimed.
    case noOrigin
    /// The *fast* route could not be resolved.
    case failed
    case resolved(fast: RoutePlan, scenic: Result<RoutePlan, ScenicUnavailable>)
}
