import Foundation
import MapKit
import Testing
@testable import Passenger

/// Two suites. `EventSeed decode` covers the parsing/boundary-validation
/// logic in isolation, against a small test fixture. `EventSeed shipped
/// seed` asserts T-034 TRD §3.4's eight-clause authoring rule against the
/// *real*, bundled `events-tel-aviv-seed.json` — the fixture C2 requires be
/// strong enough that the checks below cannot pass vacuously.
@Suite("EventSeed decode")
struct EventSeedDecodeTests {
    private final class FixtureBundleToken {}
    private static var testBundle: Bundle { Bundle(for: FixtureBundleToken.self) }
    private static let anchor = ISO8601DateFormatter().date(from: "2026-08-03T10:00:00Z")!

    @Test("a well-formed fixture decodes, offsets resolved against the given anchor")
    func decodesWellFormedFixture() throws {
        let events = try EventSeed.events(anchorHour: Self.anchor, resourceName: "events-test-fixture", bundle: Self.testBundle)
        let normal = try #require(events.first { $0.id == "fixture-normal" })
        #expect(normal.startAt == Self.anchor.addingTimeInterval(60 * 60))
        #expect(normal.endAt == Self.anchor.addingTimeInterval(180 * 60))
        #expect(normal.venueName == "A test venue")
    }

    @Test("null venue_name/category decode to nil")
    func nullFieldsDecodeToNil() throws {
        let events = try EventSeed.events(anchorHour: Self.anchor, resourceName: "events-test-fixture", bundle: Self.testBundle)
        let event = try #require(events.first { $0.id == "fixture-null-venue" })
        #expect(event.venueName == nil)
        #expect(event.category == nil)
    }

    @Test("whitespace-only venue_name/category normalize to nil, same rule PlaceCatalog/HoodCatalog apply")
    func whitespaceFieldsNormalizeToNil() throws {
        let events = try EventSeed.events(anchorHour: Self.anchor, resourceName: "events-test-fixture", bundle: Self.testBundle)
        let event = try #require(events.first { $0.id == "fixture-whitespace-venue" })
        #expect(event.venueName == nil)
        #expect(event.category == nil)
    }

    @Test("an out-of-range coordinate drops the row, never fails the whole decode")
    func badCoordinateRowDropped() throws {
        let events = try EventSeed.events(anchorHour: Self.anchor, resourceName: "events-test-fixture", bundle: Self.testBundle)
        #expect(!events.contains { $0.id == "fixture-bad-coordinate" })
    }

    @Test("a zero-duration row drops, never producing an inverted or empty interval")
    func zeroDurationRowDropped() throws {
        let events = try EventSeed.events(anchorHour: Self.anchor, resourceName: "events-test-fixture", bundle: Self.testBundle)
        #expect(!events.contains { $0.id == "fixture-zero-duration" })
    }

    @Test("a missing bundled resource throws, never returns an empty catalog silently")
    func missingResourceThrows() {
        #expect(throws: EventSeed.SeedError.self) {
            _ = try EventSeed.events(anchorHour: Self.anchor, resourceName: "does-not-exist", bundle: Self.testBundle)
        }
    }

    @Test("schemaVersion below 1 is rejected as malformed")
    func schemaVersionBelowOneThrows() {
        #expect(throws: EventSeed.SeedError.self) {
            _ = try EventSeed.events(anchorHour: Self.anchor, resourceName: "events-schema-invalid-fixture", bundle: Self.testBundle)
        }
    }
}

@Suite("EventSeed shipped seed — §3.4 authoring rule")
struct EventSeedShippedFixtureTests {
    /// Tests run hosted (`TEST_HOST = Passenger.app`), so `Bundle.main` here
    /// is the real compiled app bundle — same precedent `SettingsHintContrastTests`
    /// and `PlaceCatalogTests`' populated-config test rely on.
    private static let anchor = ISO8601DateFormatter().date(from: "2026-08-03T10:00:00Z")!

    private static func loadedEvents() throws -> [LiveEvent] {
        try EventSeed.events(anchorHour: Self.anchor)
    }

    /// Every bucket's candidate set, uncapped — `cap: .max` bypasses
    /// `EventSelection`'s default truncation so clause 3 can see the true
    /// per-bucket count before the marker cap applies.
    private static func uncappedBucket(_ offset: Int, from events: [LiveEvent]) -> [LiveEvent] {
        EventSelection.selected(from: events, anchorHour: Self.anchor, offset: offset, now: Self.anchor, cap: .max)
    }

    @Test("clause 1: at least 6 distinct hour buckets in 0...12 contain at least one event")
    func atLeastSixNonEmptyBuckets() throws {
        let events = try Self.loadedEvents()
        let nonEmptyBuckets = (0...12).filter { !Self.uncappedBucket($0, from: events).isEmpty }
        #expect(nonEmptyBuckets.count >= 6)
    }

    @Test("clause 2: at least one bucket in 0...12 contains zero events")
    func atLeastOneEmptyBucket() throws {
        let events = try Self.loadedEvents()
        let emptyBuckets = (0...12).filter { Self.uncappedBucket($0, from: events).isEmpty }
        #expect(!emptyBuckets.isEmpty)
    }

    @Test("clause 3: at least one bucket holds markerCap+2 events with distinct ranks — truncation is exercised, ordering unambiguous")
    func someBucketExceedsCapWithDistinctRanks() throws {
        let events = try Self.loadedEvents()
        let overflowBucket = (0...12).map { Self.uncappedBucket($0, from: events) }.max { $0.count < $1.count }!
        #expect(overflowBucket.count >= EventSelection.markerCap + 2)
        let ranks = overflowBucket.map(\.rank)
        #expect(Set(ranks).count == ranks.count)
    }

    @Test("clause 4: at least one event spans 3 or more hour buckets — D1's overlap rule is exercised, not assumed")
    func someEventSpansAtLeastThreeBuckets() throws {
        let events = try Self.loadedEvents()
        let maxSpan = events.map { event in
            (0...12).filter { !EventSelection.selected(from: [event], anchorHour: Self.anchor, offset: $0, now: Self.anchor).isEmpty }.count
        }.max() ?? 0
        #expect(maxSpan >= 3)
    }

    @Test("clause 5: at least one event has a nil venueName, and at least one has a nil category")
    func nilOptionalFieldsPresent() throws {
        let events = try Self.loadedEvents()
        #expect(events.contains { $0.venueName == nil })
        #expect(events.contains { $0.category == nil })
    }

    @Test("clause 6: at least one event has already ended at the anchor — req 5's stale rule is deterministically checkable")
    func atLeastOneAlreadyEndedEvent() throws {
        let events = try Self.loadedEvents()
        #expect(events.contains { $0.endAt <= Self.anchor })
    }

    @Test("clause 7: every event's coordinate falls inside its claimed hood's real bundled polygon")
    func everyCoordinateInsideItsClaimedHood() throws {
        let events = try Self.loadedEvents()
        let hoods = try HoodCatalog.load()
        let hitTester = HoodHitTester(hoods: hoods)

        for event in events {
            let hoodID = try #require(event.hoodID, "every seeded event must claim a hood")
            let resolved = hitTester.hood(at: MKMapPoint(event.coordinate), tolerance: 0)
            #expect(resolved?.id == hoodID, "\(event.id)'s coordinate does not fall inside \(hoodID)'s real polygon")
        }
    }

    @Test("clause 8 (proxy): no event or venue name collides with a real bundled place's name")
    func noNameCollidesWithARealPlace() throws {
        let events = try Self.loadedEvents()
        // `places-tel-aviv.json` isn't decodable via a public API from this
        // test target without duplicating `PlaceCatalog`'s private seed
        // type, so this reads the bundled JSON directly — a deliberately
        // narrow, single-purpose check. This is a proxy for TRD §3.4 clause
        // 8 ("plainly fictional names"), which isn't otherwise mechanically
        // checkable — it catches the specific failure mode the clause names
        // (asserting a real business is hosting a real event).
        let placesURL = try #require(Bundle.main.url(forResource: "places-tel-aviv", withExtension: "json"))
        let placesData = try Data(contentsOf: placesURL)
        let placesJSON = try #require(try JSONSerialization.jsonObject(with: placesData) as? [String: Any])
        let placeRows = try #require(placesJSON["places"] as? [[String: Any]])
        let realNames = Set(placeRows.compactMap { $0["name"] as? String })

        for event in events {
            #expect(!realNames.contains(event.name), "\(event.id)'s name collides with a real bundled place")
            if let venueName = event.venueName {
                #expect(!realNames.contains(venueName), "\(event.id)'s venue name collides with a real bundled place")
            }
        }
    }
}
