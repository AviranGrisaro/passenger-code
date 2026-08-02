import Foundation
import Testing
@testable import Passenger

/// TRD §9 row 3c: the built URL, checked directly — pure, no network, no
/// `AppConfig` singleton (§2.2's seam discipline).
@Suite("EventsAPI")
struct EventsAPITests {
    private static let anchor = ISO8601DateFormatter().date(from: "2026-08-03T10:00:00Z")!
    private static let base = URL(string: "https://example.supabase.co")!

    @Test("the built URL carries the amended query shape — select, an upper-bound-only start_at, order by rank desc")
    func urlShape() throws {
        let url = try #require(EventsAPI.buildURL(baseURL: Self.base, anchorHour: Self.anchor))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        #expect(url.path == "/rest/v1/events_public")
        #expect(items["select"] == "id,name,start_at,end_at,lat,lng,venue_name,hood_id,category,rank,source_name")
        #expect(items["order"] == "rank.desc")
        // 13h window: anchor 10:00Z -> 23:00Z.
        #expect(items["start_at"] == "lt.2026-08-03T23:00:00Z")
    }

    @Test("the amended query carries no gte lower bound — the TRD's one contract edit against live-events-pipeline §4.2")
    func noLowerBoundOnStartAt() throws {
        let url = try #require(EventsAPI.buildURL(baseURL: Self.base, anchorHour: Self.anchor))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let hasLowerBound = (components.queryItems ?? []).contains {
            $0.name == "start_at" && ($0.value ?? "").hasPrefix("gte.")
        }
        #expect(!hasLowerBound)
    }

    @Test("the URL carries nothing device- or user-specific — the exact query-item name set, no more")
    func noUserSpecificParameter() throws {
        let url = try #require(EventsAPI.buildURL(baseURL: Self.base, anchorHour: Self.anchor))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let names = Set((components.queryItems ?? []).map(\.name))
        #expect(names == ["select", "start_at", "order"])
    }

    @Test("the URL is byte-identical for the same anchor, regardless of caller — no per-call randomness")
    func byteIdenticalAcrossCalls() throws {
        let first = try #require(EventsAPI.buildURL(baseURL: Self.base, anchorHour: Self.anchor))
        let second = try #require(EventsAPI.buildURL(baseURL: Self.base, anchorHour: Self.anchor))
        #expect(first == second)
    }
}

/// `LiveEvent.init?(row:)`'s boundary validation (TRD §4.2) — the per-row
/// decode a live fetch would run through, tested directly rather than
/// through `EventStore.load()`, since `BuildPhase.eventSeedIsAuthoritative`
/// gates that branch off today (same precedent `PlaceCatalog`'s own
/// live/cache paths are tested at, per `PlaceCatalogTests`).
@Suite("LiveEvent row decoding")
struct LiveEventRowDecodingTests {
    private static func row(
        startAt: String = "2026-08-03T18:00:00Z",
        endAt: String = "2026-08-03T20:00:00Z",
        lat: Double = 32.06,
        lng: Double = 34.77,
        venueName: String? = "A venue",
        category: String? = "music"
    ) -> EventsAPI.Row {
        EventsAPI.Row(
            id: "row-1", name: "Row Event", startAt: startAt, endAt: endAt,
            lat: lat, lng: lng, venueName: venueName, hoodID: "florentin",
            category: category, rank: 0.5, sourceName: "Live"
        )
    }

    @Test("a well-formed row decodes")
    func wellFormedRowDecodes() throws {
        let event = try #require(LiveEvent(row: Self.row()))
        #expect(event.id == "row-1")
        #expect(event.venueName == "A venue")
    }

    @Test("a malformed startAt timestamp drops the row")
    func malformedStartTimestampDropsRow() {
        #expect(LiveEvent(row: Self.row(startAt: "not-a-date")) == nil)
    }

    @Test("a malformed endAt timestamp drops the row")
    func malformedEndTimestampDropsRow() {
        #expect(LiveEvent(row: Self.row(endAt: "not-a-date")) == nil)
    }

    @Test("an interval where endAt is not after startAt drops the row")
    func invertedIntervalDropsRow() {
        #expect(LiveEvent(row: Self.row(startAt: "2026-08-03T20:00:00Z", endAt: "2026-08-03T18:00:00Z")) == nil)
    }

    @Test("an out-of-range latitude drops the row")
    func outOfRangeLatitudeDropsRow() {
        #expect(LiveEvent(row: Self.row(lat: 999)) == nil)
    }

    @Test("an out-of-range longitude drops the row")
    func outOfRangeLongitudeDropsRow() {
        #expect(LiveEvent(row: Self.row(lng: 999)) == nil)
    }

    @Test("a whitespace-only venue_name normalizes to nil")
    func whitespaceVenueNormalizesToNil() throws {
        let event = try #require(LiveEvent(row: Self.row(venueName: "   ")))
        #expect(event.venueName == nil)
    }

    @Test("a fractional-seconds timestamp still decodes")
    func fractionalSecondsTimestampDecodes() throws {
        let event = try #require(LiveEvent(row: Self.row(startAt: "2026-08-03T18:00:00.500Z")))
        #expect(event.startAt.timeIntervalSince1970 > 0)
    }
}
