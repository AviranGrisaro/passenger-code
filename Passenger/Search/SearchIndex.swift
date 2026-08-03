import Foundation

/// A derived, in-memory index over the currently-loaded `Place`/`Hood`
/// catalogs (TRD §3.3, §4.2). Built once, off the cold-open path, after both
/// catalogs resolve, and rebuilt only if either catalog's identity changes.
/// Never persisted, never cached — an input to a pure function, not state.
///
/// `Search/` knows no SwiftUI, no MapKit, no network and no `DensityStore`
/// (TRD §2.2): every matching rule in this feature is unit-testable with no
/// simulator, no gesture and no fixture bundle.
struct SearchIndex: Sendable {
    struct PlaceEntry: Sendable {
        let place: Place
        let foldedName: String
        /// Parallel to `place.keywords`, same order/count — index `i` here
        /// is index `i` of the raw array, so a match can report which
        /// *original* keyword string it hit (§4.4 rule 4).
        let foldedKeywords: [String]
        /// The place's own Hood, resolved once here rather than re-looked-up
        /// per keystroke — `SearchResultRow`'s secondary line needs the
        /// properly-cased name (PRD req 4 bullet 7), so this is the display
        /// string, not a folded one.
        let hoodName: String
    }

    struct HoodEntry: Sendable {
        let hood: Hood
        let foldedName: String
    }

    let places: [PlaceEntry]
    let hoods: [HoodEntry]

    static let empty = SearchIndex(places: [], hoods: [])

    static func build(places: [Place], hoods: [Hood]) -> SearchIndex {
        let hoodNamesByID = Dictionary(uniqueKeysWithValues: hoods.map { ($0.id, $0.name) })
        let placeEntries = places.map { place in
            PlaceEntry(
                place: place,
                foldedName: fold(place.name),
                foldedKeywords: place.keywords.map(fold),
                hoodName: hoodNamesByID[place.hoodID] ?? ""
            )
        }
        let hoodEntries = hoods.map { hood in
            HoodEntry(hood: hood, foldedName: fold(hood.name))
        }
        return SearchIndex(places: placeEntries, hoods: hoodEntries)
    }

    /// The single folding rule (T-042 §4.3, adopted unchanged, TRD §4.2),
    /// used for both index entries and the live query text. `locale: nil` is
    /// explicit so the result never depends on the device's region setting —
    /// a search index whose contents shift with the user's Settings would be
    /// a bug nobody could reproduce.
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
