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
}
