import Foundation

/// What a result row *is* — either a Hood or a place, carrying the domain
/// object a selection routes to (TRD §4.3).
enum SearchResultKind: Sendable, Equatable {
    case hood(Hood)
    case place(Place, matchedKeyword: String?)   // nil == matched on name
}

/// One search-result row's data (TRD §4.3). `matchedKeyword` is carried
/// because the matcher knows it for free and a later pass (a "matched:
/// hummus" line) would otherwise need the matcher rewritten — nothing
/// renders it in V1 (D9).
struct SearchResult: Identifiable, Sendable, Equatable {
    let kind: SearchResultKind
    let id: String                 // "hood:\(id)" / "place:\(id)" — never collides
    let displayName: String        // hood.name / place.name
    let typeWord: String           // "Hood" / "Place" (D9)
    /// Non-nil only for a place row (PRD req 4 bullet 7's secondary line) —
    /// resolved once at match time from `SearchIndex.PlaceEntry.hoodName`,
    /// not re-looked-up by the view. `nil` for a Hood row, which has no
    /// second line beyond its type word.
    let hoodName: String?
    let voiceOverLabel: String     // §4.8, pinned exactly

    static func hood(_ hood: Hood) -> SearchResult {
        SearchResult(
            kind: .hood(hood),
            id: "hood:\(hood.id)",
            displayName: hood.name,
            typeWord: "Hood",
            hoodName: nil,
            voiceOverLabel: "\(hood.name), Hood"
        )
    }

    static func place(_ place: Place, matchedKeyword: String?, hoodName: String) -> SearchResult {
        SearchResult(
            kind: .place(place, matchedKeyword: matchedKeyword),
            id: "place:\(place.id)",
            displayName: place.name,
            typeWord: "Place",
            hoodName: hoodName,
            // Pinned to PRD req 8 bullet 2's own literal example — the type
            // word speaks lowercase for a place, capitalised for a Hood, and
            // carries no Hood name (§9 row 8b).
            voiceOverLabel: "\(place.name), place, \(place.category.displayName)"
        )
    }
}
