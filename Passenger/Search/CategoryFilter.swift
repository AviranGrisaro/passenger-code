import Foundation

/// The quick-filter chip state (TRD §4.5, D8). Exactly two chips exist
/// because `PlaceCategory` has exactly two cases and no `.other`
/// (`PlaceCategory.swift`'s own doc comment forbids a third) — `CategoryFilter`
/// cannot express "no categories selected" because there is no `.none` case,
/// which is Poka-Yoke at the type rather than a runtime guard
/// (`design-principles.md` §2).
enum CategoryFilter: Sendable, Equatable {
    case all
    case only(PlaceCategory)

    /// PRD req 3: both chips render active on a fresh open.
    static let fresh = CategoryFilter.all

    /// `.all` reads as every category active; `.only(c)` reads as exactly `c`.
    func isActive(_ category: PlaceCategory) -> Bool {
        switch self {
        case .all: true
        case .only(let selected): selected == category
        }
    }

    /// Tapping the chip for `category`. Selecting the only-lit chip returns
    /// to `.all` — there is no way to reach "neither chip selected."
    func toggling(_ category: PlaceCategory) -> CategoryFilter {
        switch self {
        case .all:
            .only(category)
        case .only(let selected) where selected == category:
            .all
        case .only:
            .only(category)
        }
    }
}
