/// The two-value category axis (TRD §3.2, §4.3, D4). Exactly two cases, no
/// `.other`/`.unknown` — a third value can never exist in this type, so a row
/// carrying one is dropped at the network/seed boundary rather than mapped to
/// a default (PRD req 6). Display strings live only on `displayName`; nothing
/// else in the app is allowed to spell out "Eat & Drink" or "Things to do".
enum PlaceCategory: String, Sendable, CaseIterable, Codable {
    case eatDrink = "eat-drink"
    case thingsToDo = "things-to-do"

    /// The only place a user-facing category string exists (PRD req 6, decision #33).
    var displayName: String {
        switch self {
        case .eatDrink: "Eat & Drink"
        case .thingsToDo: "Things to do"
        }
    }

    /// One glyph vocabulary across pin, place row, and category row
    /// (`map-rendering-spec.md` §4). Never a generic map pin for `.thingsToDo`.
    var symbolName: String {
        switch self {
        case .eatDrink: "fork.knife"
        case .thingsToDo: "building.columns"
        }
    }
}
