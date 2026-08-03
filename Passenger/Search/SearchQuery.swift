import Foundation

/// The pure matcher (TRD §4.4). Synchronous, total, no `async`, no `Task`, no
/// debounce — a scan of pre-folded strings is sub-millisecond even at
/// T-042's stated ~2,000-place ceiling, well inside one frame, so a debounce
/// would buy nothing and would add the one bug class this design has none
/// of: an out-of-order result set rendering after a newer keystroke.
enum SearchQuery {
    /// Rules, in order (TRD §4.4):
    /// 1. Fold and trim the query text.
    /// 2. Empty field + `.all` -> `[]` (PRD req 6's empty-field state).
    /// 3. Empty field + `.only(c)` -> every place of category `c`,
    ///    name-ascending, no Hoods (PRD req 3's category-scoped set) — a
    ///    dedicated branch so an empty query never trivially "contains" every
    ///    Hood name via `"".contains` and reads as `[]`/name-matches instead.
    /// 4. Otherwise: substring match (T-042 §4.3), name match wins over
    ///    keyword match for the same place, a place is never returned twice.
    /// 5. `filter` narrows places only — Hood results are never removed by a
    ///    chip (D8).
    /// 6. Order (D7): Hood name matches, then place name matches, then
    ///    keyword-only place matches; case-insensitive ascending on the
    ///    unfolded display name within each group.
    static func run(_ rawText: String, filter: CategoryFilter, in index: SearchIndex) -> [SearchResult] {
        let q = SearchIndex.fold(rawText.trimmingCharacters(in: .whitespacesAndNewlines))

        if q.isEmpty {
            switch filter {
            case .all:
                return []
            case .only(let category):
                return index.places
                    .filter { $0.place.category == category }
                    .sorted(by: Self.byName)
                    .map { SearchResult.place($0.place, matchedKeyword: nil, hoodName: $0.hoodName) }
            }
        }

        let hoodMatches = index.hoods.filter { $0.foldedName.contains(q) }

        var nameMatches: [SearchIndex.PlaceEntry] = []
        var keywordMatches: [(entry: SearchIndex.PlaceEntry, keyword: String)] = []
        for entry in index.places {
            if entry.foldedName.contains(q) {
                nameMatches.append(entry)
            } else if let hitIndex = entry.foldedKeywords.firstIndex(where: { $0.contains(q) }) {
                keywordMatches.append((entry, entry.place.keywords[hitIndex]))
            }
        }

        // D8: the chip narrows places only. Hoods are never filtered by it.
        let filteredNameMatches = nameMatches.filter { filter.isActive($0.place.category) }
        let filteredKeywordMatches = keywordMatches.filter { filter.isActive($0.entry.place.category) }

        let hoods = hoodMatches
            .sorted { $0.hood.name.localizedCaseInsensitiveCompare($1.hood.name) == .orderedAscending }
            .map { SearchResult.hood($0.hood) }
        let names = filteredNameMatches
            .sorted(by: Self.byName)
            .map { SearchResult.place($0.place, matchedKeyword: nil, hoodName: $0.hoodName) }
        let keywords = filteredKeywordMatches
            .sorted { $0.entry.place.name.localizedCaseInsensitiveCompare($1.entry.place.name) == .orderedAscending }
            .map { SearchResult.place($0.entry.place, matchedKeyword: $0.keyword, hoodName: $0.entry.hoodName) }

        return hoods + names + keywords
    }

    private static func byName(_ lhs: SearchIndex.PlaceEntry, _ rhs: SearchIndex.PlaceEntry) -> Bool {
        lhs.place.name.localizedCaseInsensitiveCompare(rhs.place.name) == .orderedAscending
    }
}
