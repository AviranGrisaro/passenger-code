import SwiftUI

/// The two-level presentation state machine (TRD §4.1). Entry path is
/// derived, never passed — "reached via the Hood sheet" *is* `hood != nil`.
/// There is no `entryPath` parameter to keep in sync with reality.
@MainActor
@Observable
final class DetailRouter {
    private(set) var hood: Hood?
    private(set) var place: Place?
    /// T-034 TRD §4.7, D6: a third depth-1 destination, mutually exclusive
    /// with both `hood` and `place`.
    private(set) var event: LiveEvent?

    /// `hood = hood; place = nil; event = nil`. Clears any open place modal
    /// and any open event sheet — tapping a different Hood while a place
    /// modal is open at depth 1 swaps the depth-1 destination in place
    /// rather than stacking, and the three depth-1 destinations are mutually
    /// exclusive (T-034 trd-review fold-in: `openHood` must clear `event`
    /// the same way `openEvent` clears `hood`/`place`, or the
    /// mutual-exclusivity claim only holds in one direction).
    func openHood(_ hood: Hood) {
        self.hood = hood
        self.place = nil
        self.event = nil
    }

    /// `place = place; hood unchanged; event = nil`. A pin tap on the
    /// exposed map while the Hood sheet is open lands at depth 2 — correct,
    /// the user is still inside that Hood's context. Also clears `event`: a
    /// place opening as a *new* depth-1 destination (tapped directly on the
    /// map, no Hood open) is mutually exclusive with an open event sheet,
    /// same trd-review fold-in as `openHood` above. A no-op on the depth-2
    /// nesting path, where `event` is already `nil` by `openHood`'s own
    /// postcondition.
    func openPlace(_ place: Place) {
        self.place = place
        self.event = nil
    }

    /// `event = event; hood = nil; place = nil`. Always depth 1, and
    /// mutually exclusive with both other destinations (T-034 TRD §4.7,
    /// D6) — an event replaces whatever was open, matching `openHood`'s own
    /// swap-in-place behaviour, rather than stacking as a third router
    /// level the state machine deliberately cannot express.
    func openEvent(_ event: LiveEvent) {
        self.event = event
        self.hood = nil
        self.place = nil
    }

    /// Clears the place only, leaving the Hood sheet standing — "exactly one
    /// level up" (design spec §1).
    func closePlace() {
        place = nil
    }

    /// Clears the event only.
    func closeEvent() {
        event = nil
    }

    /// Clears all three fields.
    func closeHood() {
        hood = nil
        place = nil
        event = nil
    }

    /// `nil` when no modal is open. Never returns a value greater than 2 —
    /// structural, since there is no third field to hold a deeper level.
    var placeDepth: Int? {
        place == nil ? nil : (hood == nil ? 1 : 2)
    }

    /// Site A's presence flag (TRD §4.2, extended by T-034 TRD §4.7 for
    /// `event`). Originally `.sheet(isPresented:)`'s own binding; Site A
    /// moved off `.sheet()` to a custom overlay (T-079/`PAS-73` re-fix,
    /// `product` REJECT 2026-08-07 — see `MapScreen.body`'s `.overlay`
    /// comment), but this `Binding` stays: `MapScreen` still reads
    /// `.wrappedValue` to gate the overlay and to drive a couple of other
    /// state cleanups (`onChange`, `EdgeAvailability`). Writing `true` is
    /// ignored — a presentation here is only ever opened by
    /// `openHood`/`openPlace`/`openEvent`, never by writing the binding.
    /// Writing `false` is the drag-to-dismiss path: routed into
    /// `closeHood()`, which now also clears `event`, so a depth-1 dismiss
    /// cannot strand a place or leave a stale event behind.
    var isDepth1Presented: Binding<Bool> {
        Binding(
            get: { self.hood != nil || self.place != nil || self.event != nil },
            set: { newValue in if !newValue { self.closeHood() } }
        )
    }

    /// Site B's presence flag, inside `HoodSheet` (TRD §4.2). Originally
    /// `.sheet(isPresented:)`'s own binding; Site B moved off `.sheet()`
    /// the same pass as Site A (`HoodSheet` now embeds `PlaceDetailModal`
    /// directly, calling `closePlace()` from its own scrim/drag gesture
    /// rather than through this `Binding`) — kept as a small, still-useful
    /// "is a place open under this Hood" query, covered by
    /// `DetailRouterTests`. Writing `false` routes to `closePlace()` only —
    /// leaves the Hood sheet standing.
    var isDepth2Presented: Binding<Bool> {
        Binding(
            get: { self.hood != nil && self.place != nil },
            set: { newValue in if !newValue { self.closePlace() } }
        )
    }
}
