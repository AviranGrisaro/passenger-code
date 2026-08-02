import CoreLocation
import Foundation
import Testing
@testable import Passenger

/// Covers TRD §4.7's "omitted, not blank" rule (req 4 bullet 3) at the array
/// level — a `nil` field must never produce a row, checked directly on
/// `EventDetailRows.rows(for:)` rather than by rendering anything.
@Suite("EventDetailRows")
struct EventDetailRowsTests {
    private static func event(venueName: String?, hoodID: String?, category: String?) -> LiveEvent {
        LiveEvent(
            id: "e", name: "Test Event", startAt: Date(), endAt: Date().addingTimeInterval(3600),
            coordinate: CLLocationCoordinate2D(latitude: 32.06, longitude: 34.77),
            venueName: venueName, hoodID: hoodID, category: category, rank: 0.5, sourceName: nil
        )
    }

    @Test("every optional field present renders every row, in order")
    func allFieldsPresentRendersAllRows() {
        let event = Self.event(venueName: "A venue", hoodID: "florentin", category: "music")
        #expect(EventDetailRows.rows(for: event) == [.name, .time, .venue, .hood, .category])
    }

    @Test("a nil venue omits the venue row, never renders it blank")
    func nilVenueOmitsRow() {
        let event = Self.event(venueName: nil, hoodID: "florentin", category: "music")
        let rows = EventDetailRows.rows(for: event)
        #expect(!rows.contains(.venue))
        #expect(rows.contains(.hood))
        #expect(rows.contains(.category))
    }

    @Test("a nil hoodID omits the hood row")
    func nilHoodOmitsRow() {
        let event = Self.event(venueName: "A venue", hoodID: nil, category: "music")
        #expect(!EventDetailRows.rows(for: event).contains(.hood))
    }

    @Test("a nil category omits the category row")
    func nilCategoryOmitsRow() {
        let event = Self.event(venueName: "A venue", hoodID: "florentin", category: nil)
        #expect(!EventDetailRows.rows(for: event).contains(.category))
    }

    @Test("all three optional fields nil leaves only name and time")
    func allOptionalFieldsNilLeavesNameAndTime() {
        let event = Self.event(venueName: nil, hoodID: nil, category: nil)
        #expect(EventDetailRows.rows(for: event) == [.name, .time])
    }
}
