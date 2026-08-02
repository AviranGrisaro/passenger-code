import CoreLocation
import Foundation

/// One live event, mirroring `events_public` exactly (TRD §3.1). `Events/`
/// knows no map and no view — this is identity, timing, and geometry only,
/// the same discipline `Place`/`Hood` hold in their own modules.
struct LiveEvent: Identifiable, Sendable {
    let id: String                  // uuid string from the server; stable across fetches
    let name: String
    let startAt: Date
    let endAt: Date
    let coordinate: CLLocationCoordinate2D
    let venueName: String?          // nil == not supplied; never "" (§4.1)
    let hoodID: String?
    let category: String?
    let rank: Double                // sort key only (§4.4) — never re-derived, never used elsewhere
    let sourceName: String?         // decoded, deliberately not rendered in V1 (D5 note)

    /// VoiceOver label / detail-sheet time row — "6:00 PM–10:00 PM". No date
    /// component: every event in the 13h window is "today" from the user's
    /// perspective (§4.2's window is `[anchorHour, anchorHour+13h)`).
    var timeLabel: String {
        "\(startAt.formatted(date: .omitted, time: .shortened))–\(endAt.formatted(date: .omitted, time: .shortened))"
    }
}

extension LiveEvent: Hashable {
    // `CLLocationCoordinate2D` has no Equatable/Hashable conformance of its
    // own in this SDK (same reason `Hood`/`Place` give) — hash and compare
    // on `id`, the stable server uuid (T-043 §3.2).
    static func == (lhs: LiveEvent, rhs: LiveEvent) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension LiveEvent {
    /// Boundary validation for a live-fetched row (§4.2, Build Phase 3): a
    /// malformed timestamp, an inverted/zero-length interval, or an
    /// out-of-range coordinate drops the row — never fails the batch, never
    /// crashes (`passenger-code/CLAUDE.md` fail-fast-at-boundaries rule),
    /// mirroring `PlaceCatalog.apply(hoodRows:)`'s per-row validation.
    init?(row: EventsAPI.Row) {
        let strict = ISO8601DateFormatter()
        strict.formatOptions = [.withInternetDateTime]
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard
            let startAt = strict.date(from: row.startAt) ?? fractional.date(from: row.startAt),
            let endAt = strict.date(from: row.endAt) ?? fractional.date(from: row.endAt),
            endAt > startAt,
            (-90...90).contains(row.lat),
            (-180...180).contains(row.lng)
        else { return nil }

        self.init(
            id: row.id,
            name: row.name,
            startAt: startAt,
            endAt: endAt,
            coordinate: CLLocationCoordinate2D(latitude: row.lat, longitude: row.lng),
            venueName: Self.normalized(row.venueName),
            hoodID: row.hoodID,
            category: Self.normalized(row.category),
            rank: row.rank,
            sourceName: Self.normalized(row.sourceName)
        )
    }

    /// `""`/whitespace-only normalises to `nil` — same rule `PlaceCatalog`/`HoodCatalog` apply.
    fileprivate static func normalized(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return raw
    }
}
