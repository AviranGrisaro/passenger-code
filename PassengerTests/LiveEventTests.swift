import CoreLocation
import Foundation
import Testing
@testable import Passenger

@Suite("LiveEvent")
struct LiveEventTests {
    private static func event(id: String = "a", startAt: Date, endAt: Date) -> LiveEvent {
        LiveEvent(
            id: id, name: "Test Event", startAt: startAt, endAt: endAt,
            coordinate: CLLocationCoordinate2D(latitude: 32.06, longitude: 34.77),
            venueName: nil, hoodID: nil, category: nil, rank: 0.5, sourceName: nil
        )
    }

    @Test("equality and hashing are keyed on id alone, same rule Hood/Place hold")
    func equalityIsIDOnly() {
        let start = Date()
        let a = Self.event(id: "same", startAt: start, endAt: start.addingTimeInterval(3600))
        let b = Self.event(id: "same", startAt: start.addingTimeInterval(60), endAt: start.addingTimeInterval(7200))
        #expect(a == b)
    }

    @Test("two events with different ids are never equal, even with identical timing")
    func differentIDsAreNeverEqual() {
        let start = Date()
        let a = Self.event(id: "a", startAt: start, endAt: start.addingTimeInterval(3600))
        let b = Self.event(id: "b", startAt: start, endAt: start.addingTimeInterval(3600))
        #expect(a != b)
    }

    @Test("timeLabel formats as a start–end range with no date component")
    func timeLabelFormatsAsRange() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 3
        components.hour = 18; components.minute = 0
        var timeZoneCalendar = calendar
        timeZoneCalendar.timeZone = TimeZone(identifier: "UTC")!
        let start = timeZoneCalendar.date(from: components)!
        let end = start.addingTimeInterval(4 * 3600)

        let label = Self.event(startAt: start, endAt: end).timeLabel
        // Locale/24h-vs-12h formatting varies by test environment, so this
        // checks structure (an en dash separating two non-empty halves)
        // rather than an exact locale-dependent string.
        #expect(label.contains("–"))
        let halves = label.split(separator: "–")
        #expect(halves.count == 2)
        #expect(halves.allSatisfy { !$0.isEmpty })
    }
}
