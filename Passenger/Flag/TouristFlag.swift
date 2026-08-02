/// Pure vocabulary (TRD §2.2): no SwiftUI, no MapKit, no store. `Flag/`
/// answers "given a `Bool?` and a `HeatBand?`, what treatment and what
/// words" — every P0 rendering rule for the tourist-trap flag is decided
/// inside this module, which is what makes reqs 1–5 and 7 unit-testable
/// without a simulator.

/// Three states, never a boolean — matches `Hood.isTouristTrap`/
/// `Place.isTouristTrap`'s own `Bool?` storage (TRD §3.1).
enum TouristFlag: Equatable, CaseIterable {
    case flagged
    case notFlagged
    case unrated

    init(_ raw: Bool?) {
        switch raw {
        case true: self = .flagged
        case false: self = .notFlagged
        case nil: self = .unrated
        }
    }
}

/// The whole rendering decision (TRD §4.1). A single-value enum, not an
/// option set or two booleans — "replaces, never stacks" (req 5) is
/// guaranteed by the type, not by an `if`/`else` a future edit could turn
/// into two conditions that both fire (§8 D2).
enum FlagStroke: Equatable, CaseIterable {
    case none
    case plain
    case busyWarning

    /// Total over 3×4 inputs (`TouristFlag` × `HeatBand?`). Zoom is
    /// deliberately not a parameter here — whether this treatment is ever
    /// actually drawn is `HoodLayer`'s own zoom-tier gate (TRD §2.3), kept
    /// separate so this function stays a pure mapping from flag state alone.
    static func treatment(for flag: TouristFlag, band: HeatBand?) -> FlagStroke {
        guard flag == .flagged else { return .none }
        return band == .busy ? .busyWarning : .plain
    }
}
