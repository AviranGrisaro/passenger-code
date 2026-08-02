/// One VoiceOver announcement per Places-list row, clauses appended in a
/// fixed order — `map-rendering-spec.md` §7's established construction
/// ("Port Said, Eat & Drink, in your Places"), extended with the provenance
/// word and, when closed, a trailing clause (TRD §4.8). Pure and
/// unit-tested over the full 3 × 2 matrix — no simulator, no VoiceOver
/// session needed to prove the strings. The tourist-heavy clause is T-035's
/// to append when it fills its reserved slot.
enum PlacesRowLabel {
    /// e.g. "Nachum Gutman Museum, Things to do, Visited, permanently closed"
    static func label(name: String, category: PlaceCategory, provenance: PlaceProvenance, isClosed: Bool) -> String {
        var clauses = [name, category.displayName, provenance.word]
        if isClosed {
            clauses.append("permanently closed")
        }
        return clauses.joined(separator: ", ")
    }
}
