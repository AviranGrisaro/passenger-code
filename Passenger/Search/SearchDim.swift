import Foundation

/// The map's selective dim while search is open (TRD §4.10). Derived from
/// the current result set on every render pass — there is no dim state to
/// leave stale, because it is never anything but a pure function of
/// `[SearchResult]`.
enum SearchDim {
    /// `nil` when there is nothing to emphasise (an empty result set) — the
    /// other half of TRD §4.10's "`nil` whenever `.search` is not presented
    /// or `results.isEmpty`" rule is the caller's job: `MapScreen` only
    /// calls this while `.search` is presented, so the surface-presented
    /// check never needs to live here.
    ///
    /// A place match also emphasises that place's own Hood (T-038/PAS-29's
    /// second acceptance pass, F1b): `PlaceLayer` only renders at
    /// `.close` zoom (`MapScreen.showsNames`), so a place-only match at any
    /// wider zoom — including the cold-open camera — has no pin to show at
    /// all. `HoodLayer` has no such zoom gate, so its own Hood is always
    /// something the map can visibly emphasise, whether or not the pin
    /// itself happens to be on screen. This makes PRD req 4's "something is
    /// visibly emphasised … at every zoom the map can be at" true regardless
    /// of pin visibility, at the cost of a Hood match and a place match in
    /// the same Hood becoming indistinguishable in the dim set — acceptable
    /// since the requirement is about *something* being emphasised, not
    /// about the emphasis set proving which kind of match caused it.
    static func emphasis(results: [SearchResult]) -> (places: Set<Place.ID>, hoods: Set<Hood.ID>)? {
        guard !results.isEmpty else { return nil }

        var places: Set<Place.ID> = []
        var hoods: Set<Hood.ID> = []
        for result in results {
            switch result.kind {
            case .hood(let hood):
                hoods.insert(hood.id)
            case .place(let place, _):
                places.insert(place.id)
                hoods.insert(place.hoodID)
            }
        }
        return (places, hoods)
    }
}
