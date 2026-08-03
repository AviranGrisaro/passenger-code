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
            }
        }
        return (places, hoods)
    }
}
