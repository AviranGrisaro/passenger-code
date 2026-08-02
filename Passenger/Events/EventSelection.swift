import Foundation

/// The whole of req 3, in one pure function (TRD §4.4). No store, no clock of
/// its own, no network — `now` is always injected, so this tests with no
/// simulator.
enum EventSelection {
    /// [ASSUMPTION] §8 D3. One constant, one call site. Derivation: Tel Aviv
    /// is a couple of dozen Hoods (decision #12), so 12 markers is on the
    /// order of one per two Hoods at city-wide zoom — punctuation over a fill
    /// layer rather than a second surface competing with it. The PRD's own
    /// open question defers the real number to real event volume, which
    /// doesn't exist yet.
    static let markerCap = 12

    /// Three steps, in order, and nothing else: **filter** by §4.3's overlap
    /// predicate → **sort** by `(rank descending, startAt ascending, id
    /// ascending)` → **`prefix(cap)`**. Called once per render pass, off the
    /// same one-resolution-per-pass seam T-032 introduces for heat — never
    /// per marker.
    static func selected(
        from events: [LiveEvent],
        anchorHour: Date,
        offset: Int,
        now: Date,
        cap: Int = markerCap
    ) -> [LiveEvent] {
        let bucketStart = anchorHour.addingTimeInterval(Double(offset) * 3600)
        let bucketEnd = bucketStart.addingTimeInterval(3600)

        // §4.3: an event belongs to hour offset `k` when its interval
        // intersects that bucket — not only when it *starts* inside it. The
        // `endAt > now` clause is req 5 bullet 2's stale rule, folded into
        // the same predicate rather than a second pass.
        let overlapping = events.filter { event in
            event.startAt < bucketEnd && event.endAt > bucketStart && event.endAt > now
        }

        // A total order: rank ties broken by start time, then by the
        // server's stable uuid — the rendered set cannot churn between two
        // renders of the same data (§4.4).
        let sorted = overlapping.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
            if lhs.startAt != rhs.startAt { return lhs.startAt < rhs.startAt }
            return lhs.id < rhs.id
        }

        return Array(sorted.prefix(cap))
    }
}
