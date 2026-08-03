import Foundation

/// The query text and chip selection, owned by `MapScreen` as `@State`, not
/// by `SearchOverlay` (TRD §4.6) — a view that leaves the hierarchy takes its
/// `@State` with it, so query text held inside the overlay would die on
/// every nav switch, which is precisely what PRD req 7 forbids. Nothing here
/// is written to disk, `UserDefaults`, or a cache (PRD req 7's "nothing
/// persists across launches" is a property of where the value lives).
@MainActor
@Observable
final class SearchSession {
    var text: String = ""
    var filter: CategoryFilter = .fresh

    /// The ONLY mutation that resets both, called from exactly the paths
    /// that *complete* a search (a result tap, ✕, drag-past-threshold,
    /// tap-outside, re-tapping the search button while open) — never from an
    /// interruption (switching to another nav surface), which must leave the
    /// session standing (PRD req 7, TRD §4.6/D10).
    func clear() {
        text = ""
        filter = .fresh
    }
}
