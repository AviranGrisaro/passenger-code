/// Ordered lowest → highest. Precedence (PRD req 1, TRD §4.1) is `max`,
/// structurally: there is no branch anyone can get backwards.
enum PlaceProvenance: Int, Comparable, Sendable, CaseIterable {
    case visited = 0
    case been = 1
    case saved = 2

    /// The one user-facing word. Nothing else in the app spells these out.
    var word: String {
        switch self {
        case .saved: "Saved"
        case .been: "Been"
        case .visited: "Visited"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// What a detector (or, in Build Phase 1, the bundled fixture) can produce.
/// Deliberately a separate type from `PlaceProvenance`: the visit source
/// **cannot** claim `.saved`, because that value does not exist in this enum
/// (TRD §4.1).
enum VisitKind: String, Codable, Sendable {
    case been, visited
    var provenance: PlaceProvenance { self == .been ? .been : .visited }
}
