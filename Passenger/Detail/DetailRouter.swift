import SwiftUI

/// The two-level presentation state machine (TRD §4.1). Entry path is
/// derived, never passed — "reached via the Hood sheet" *is* `hood != nil`.
/// There is no `entryPath` parameter to keep in sync with reality.
@MainActor
@Observable
final class DetailRouter {
    private(set) var hood: Hood?
    private(set) var place: Place?

    /// `hood = hood; place = nil`. Clears any open place modal — tapping a
    /// different Hood while a place modal is open at depth 1 swaps the
    /// depth-1 destination in place rather than stacking.
    func openHood(_ hood: Hood) {
        self.hood = hood
        self.place = nil
    }

    /// `place = place; hood unchanged`. A pin tap on the exposed map while
    /// the Hood sheet is open lands at depth 2 — correct, the user is still
    /// inside that Hood's context.
    func openPlace(_ place: Place) {
        self.place = place
    }

    /// Clears the place only, leaving the Hood sheet standing — "exactly one
    /// level up" (design spec §1).
    func closePlace() {
        place = nil
    }

    /// Clears both fields.
    func closeHood() {
        hood = nil
        place = nil
    }

    /// `nil` when no modal is open. Never returns a value greater than 2 —
    /// structural, since there is no third field to hold a deeper level.
    var placeDepth: Int? {
        place == nil ? nil : (hood == nil ? 1 : 2)
    }

    /// `.sheet(isPresented:)` at site A (TRD §4.2). Writing `true` is ignored
    /// — a sheet here is only ever opened by `openHood`/`openPlace`, never by
    /// writing the binding. Writing `false` is the swipe-to-dismiss path:
    /// routed into `closeHood()` so a depth-1 dismiss cannot strand a place.
    var isDepth1Presented: Binding<Bool> {
        Binding(
            get: { self.hood != nil || self.place != nil },
            set: { newValue in if !newValue { self.closeHood() } }
        )
    }

    /// `.sheet(isPresented:)` at site B, inside `HoodSheet` (TRD §4.2).
    /// Writing `false` routes to `closePlace()` only — leaves the Hood
    /// sheet standing.
    var isDepth2Presented: Binding<Bool> {
        Binding(
            get: { self.hood != nil && self.place != nil },
            set: { newValue in if !newValue { self.closePlace() } }
        )
    }
}
