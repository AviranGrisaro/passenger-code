/// One spoken sentence per Hood, total over 3×4 inputs (`TouristFlag` ×
/// `HeatBand?`, TRD §4.2). Extends `HoodLayer`'s existing no-data branch
/// (`"\(hood.name), no data right now"`) rather than replacing it — the
/// map-rendering-spec.md §7 rule that VoiceOver states the flag even when
/// nothing renders visually (req 7) applies whether or not density resolved.
enum HoodSpeech {
    static func label(name: String, band: HeatBand?, flag: TouristFlag) -> String {
        // Its own combined form (req 7 bullet 2) — never two clauses
        // concatenated, so VoiceOver doesn't ask a listener to infer the
        // combination themselves (design reference, carried into the TRD).
        if flag == .flagged, band == .busy {
            return "\(name), busy and tourist-heavy — worth a second look"
        }
        guard let band else {
            return "\(name), no data right now, \(flagClause(flag))"
        }
        return "\(name), \(band.spokenWord), \(flagClause(flag))"
    }

    private static func flagClause(_ flag: TouristFlag) -> String {
        switch flag {
        case .flagged: "tourist-heavy spot"
        case .notFlagged: "not a tourist-heavy spot"
        case .unrated: "no local rating yet"
        }
    }
}
