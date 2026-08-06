/// Makes req 4 bullet 3 ("omitted, not blank") unit-testable rather than
/// eyeballed (TRD §4.7). `EventDetailModal` iterates this array — a `nil`
/// field cannot produce a row, because the row is never in the list. Any
/// `if let` inline in the view instead of a case here is a review finding:
/// the point of the type is that the requirement is checkable without
/// rendering anything.
enum EventDetailRows {
    enum Row: Equatable, Hashable {
        case name, time, venue, hood, category
    }

    /// Pure. The rows this event actually renders, in order. `name`/`time`
    /// are unconditional (every `LiveEvent` has both); `venue`/`hood`/
    /// `category` appear only when their field is non-nil.
    static func rows(for event: LiveEvent) -> [Row] {
        var rows: [Row] = [.name, .time]
        if event.venueName != nil { rows.append(.venue) }
        if event.hoodID != nil { rows.append(.hood) }
        if event.category != nil { rows.append(.category) }
        return rows
    }

    /// T-052/PAS-40: `event.category` carries no fixed taxonomy the way
    /// `Place`/`PlaceCategory` does — it's an arbitrary string from the
    /// events pipeline (TRD §4.2: "if the pipeline supplies a category worth
    /// trusting"), so there is no enum to render a `displayName` off of.
    /// Humanizes the raw value instead of ever rendering it verbatim:
    /// hyphens/underscores read as separators, not real characters, and
    /// every word is capitalized ("live-jazz" -> "Live Jazz"). Pure, so
    /// `EventDetailModal` needn't render anything to check it.
    static func displayCategory(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
