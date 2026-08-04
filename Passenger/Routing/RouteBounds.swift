import Foundation

/// The detour is bounded, and so is the search for one (TRD §4.6). Every
/// constant lives here, in one file, because §8 R3 names them as the tunable
/// knobs if "no scenic alternative" turns out to fire too often in practice.
enum RouteBounds {
    /// PRD req 3 — ratified.
    static let detourTimeMultiplier = 1.5
    /// PRD req 3 — ratified. +15 min.
    static let detourTimeCeiling: TimeInterval = 900
    /// Added by the TRD. **[ASSUMPTION].** A 4-minute walk has no room for a
    /// scenic alternative; 1.5× of it is two extra minutes, which is noise
    /// offered as a choice.
    static let minimumFastTravelTime: TimeInterval = 300
    /// Wall clock, for the whole resolve — structural, not hoped-for (TRD
    /// §4.6).
    static let resolveBudget: TimeInterval = 2.5
    static let maximumCandidateAttempts = 2

    /// The corridor buffer around the fast route's own polyline (TRD §4.5a).
    static let corridorBuffer: Double = 800
    /// A waypoint closer than this to the fast route would make the scenic
    /// route "the fast route with extra steps" (TRD §4.5, filter 4).
    static let minimumOffRoute: Double = 250
    /// A waypoint farther than this cannot survive `accepts` on any
    /// realistic walk — rejected before spending a request on it.
    static let maximumOffRoute: Double = 1200

    /// The PRD's "≤ 1.5× **and** ≤ +15 min" is a `min`, not two independent
    /// tests (TRD §4.6).
    static func accepts(scenic: TimeInterval, fast: TimeInterval) -> Bool {
        scenic <= min(fast * detourTimeMultiplier, fast + detourTimeCeiling)
    }
}
