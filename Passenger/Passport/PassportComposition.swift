/// One sticker per Been place (passport TRD §4.1, req 3). `place` is the
/// full `Place`, not just an id — the album needs the name and the sticker
/// label needs the shape word, and this is a derived value, not a store, so
/// there is no invalidation cost to holding the whole struct.
struct PassportSticker: Identifiable, Sendable, Equatable {
    let place: Place
    let shape: StickerShape
    var id: Place.ID { place.id }
}

/// One designated Hood's progress toward Local (req 4). Undesignated Hoods
/// never produce one of these — `PassportComposition.progress` filters them
/// out entirely, so there is no "present at zero" state for a view to
/// accidentally render.
struct HoodProgress: Identifiable, Sendable, Equatable {
    let hood: Hood
    let beenCount: Int
    var id: Hood.ID { hood.id }
    var isLocal: Bool { LocalStatus.isLocal(beenCount: beenCount) }
}

/// The whole feature's logic (TRD §4.1, D1) — pure functions over three
/// already-loaded stores, never a store of its own. Mirrors
/// `PlacesListComposition`'s reasoning exactly: a derived `@Observable`
/// store computed from three other stores has an invalidation problem; a
/// function cannot go stale.
enum PassportComposition {
    /// One sticker per Been place. `.visited` yields none — the filter is on
    /// `VisitKind`, so "a Visited place earns no sticker" has no branch
    /// anyone can get backwards, and a Saved-only place (absent from
    /// `visits` entirely) yields none for the same structural reason. A
    /// visit id with no matching `Place` is skipped, not defaulted — this
    /// walks `places`, so an id in `visits` that names no place is simply
    /// never looked up. Revisits add none: `visits` already holds at most
    /// one `VisitKind` per place (`BundledVisitSource.keepHigherKind`), so
    /// there is nothing here to deduplicate. Name-ascending, id-tiebroken —
    /// deterministic, so §9 row 3's fixture assertion is falsifiable.
    static func stickers(places: [Place], visits: [Place.ID: VisitKind], registry: PlaceTypeRegistry) -> [PassportSticker] {
        places
            .filter { visits[$0.id] == .been }
            .map { place in PassportSticker(place: place, shape: registry.shape(for: place.placeType)) }
            .sorted { lhs, rhs in
                lhs.place.name == rhs.place.name
                    ? lhs.place.id < rhs.place.id
                    : lhs.place.name < rhs.place.name
            }
    }

    /// Designated Hoods only (req 4). An undesignated Hood produces no
    /// `HoodProgress` at all — absent from the output, never present with a
    /// zero — the [ASSUMPTION] the PRD carries, made structural here so no
    /// view can accidentally render one. Name-ascending, id-tiebroken.
    static func progress(hoods: [Hood], places: [Place], visits: [Place.ID: VisitKind]) -> [HoodProgress] {
        hoods
            .filter(\.designatedForProgression)
            .map { hood in
                let beenCount = places.filter { $0.hoodID == hood.id && visits[$0.id] == .been }.count
                return HoodProgress(hood: hood, beenCount: beenCount)
            }
            .sorted { lhs, rhs in
                lhs.hood.name == rhs.hood.name
                    ? lhs.hood.id < rhs.hood.id
                    : lhs.hood.name < rhs.hood.name
            }
    }

    /// req 4 bullet 2. `false` when the designated set is empty — an empty
    /// `allSatisfy` is `true`, and "Local everywhere" with nowhere
    /// designated is the one answer that must never render, so the empty
    /// check is written explicitly rather than trusted to fall out of
    /// `allSatisfy` alone.
    static func isOverallLocal(_ progress: [HoodProgress]) -> Bool {
        !progress.isEmpty && progress.allSatisfy(\.isLocal)
    }
}
