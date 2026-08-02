/// One row of the Places list — a `Place` paired with the one provenance it
/// renders under (TRD §4.3). "Every row shows exactly one of
/// Saved/Been/Visited — never two, never none" is a property of
/// `provenance` being a single non-optional value here, not a rule a view
/// has to honour.
struct PlacesListEntry: Identifiable, Sendable, Equatable {
    let place: Place
    let provenance: PlaceProvenance
    var id: Place.ID { place.id }
}

/// The read-time precedence merge (PRD req 1, TRD §4.3, D3) — a pure
/// function over two independent stores, not a third store. A derived
/// `@Observable` store would hold state computed from two other stores and
/// would need invalidation; a function cannot go stale.
enum PlacesListComposition {
    /// One entry per place that has any provenance, in name-ascending order
    /// (`id` as tiebreak — TRD §4.4, D4). A saved or visited id with no
    /// matching `Place` is **skipped, not deleted** — there is nothing to
    /// render without a name and category, and the underlying record
    /// survives so the row returns if the place returns to the dataset.
    static func entries(
        places: [Place],
        saved: Set<Place.ID>,
        visits: [Place.ID: VisitKind]
    ) -> [PlacesListEntry] {
        places
            .compactMap { place in
                provenance(for: place.id, saved: saved, visits: visits)
                    .map { PlacesListEntry(place: place, provenance: $0) }
            }
            .sorted { lhs, rhs in
                lhs.place.name == rhs.place.name
                    ? lhs.place.id < rhs.place.id
                    : lhs.place.name < rhs.place.name
            }
    }

    /// The map ring's predicate (PRD req 7) — binary, provenance-blind,
    /// O(1). Must agree with `entries` on every place; never a linear scan.
    static func isListed(_ id: Place.ID, saved: Set<Place.ID>, visits: [Place.ID: VisitKind]) -> Bool {
        provenance(for: id, saved: saved, visits: visits) != nil
    }

    /// Saved beats Been beats Visited — `max`, structurally, via
    /// `PlaceProvenance: Comparable`. Checking `saved` first and returning
    /// immediately is that `max` with the branch that can never lose taken
    /// first; there is no code path here where a lower provenance can win.
    private static func provenance(
        for id: Place.ID, saved: Set<Place.ID>, visits: [Place.ID: VisitKind]
    ) -> PlaceProvenance? {
        if saved.contains(id) { return .saved }
        return visits[id]?.provenance
    }
}
