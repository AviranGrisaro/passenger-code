import Foundation
import Testing
@testable import Passenger

/// TRD §4.4, §9 row 5. Injected clock/calendar throughout — no simulator,
/// no fixed timezone assumed.
@Suite("HourFormat")
struct HourFormatTests {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    @Test("offset 0 reads 'Now', never a bare clock time")
    func offsetZeroReadsNow() {
        let anchor = Self.date("2026-07-30T18:00:00Z")
        let readout = HourFormat.readout(offset: 0, anchorHour: anchor, now: anchor, calendar: Self.utcCalendar)
        #expect(readout.offsetLabel == "Now")
        #expect(readout.clockLabel == "18:00")
    }

    @Test("every offset 0...12 produces a non-empty offsetLabel")
    func everyOffsetHasALabel() {
        let anchor = Self.date("2026-07-30T18:00:00Z")
        for offset in 0...12 {
            let readout = HourFormat.readout(offset: offset, anchorHour: anchor, now: anchor, calendar: Self.utcCalendar)
            #expect(!readout.offsetLabel.isEmpty)
        }
    }

    @Test("offset 12 reads '+12h'")
    func offsetTwelveReadsPlusTwelve() {
        let anchor = Self.date("2026-07-30T18:00:00Z")
        let readout = HourFormat.readout(offset: 12, anchorHour: anchor, now: anchor, calendar: Self.utcCalendar)
        #expect(readout.offsetLabel == "+12h")
        #expect(readout.clockLabel == "06:00")  // 18:00 + 12h wraps to 06:00
    }

    @Test("a midnight-crossing offset sets isNextDay, compared against the real clock")
    func midnightCrossingSetsIsNextDay() {
        let anchor = Self.date("2026-07-30T22:00:00Z")
        let now = anchor  // "now" is when the control was opened
        // +3h from 22:00 lands at 01:00 the following day.
        let readout = HourFormat.readout(offset: 3, anchorHour: anchor, now: now, calendar: Self.utcCalendar)
        #expect(readout.isNextDay)
        #expect(readout.clockLabel == "01:00")
    }

    @Test("an offset that stays within the same day as now does not set isNextDay")
    func sameDayDoesNotSetIsNextDay() {
        let anchor = Self.date("2026-07-30T10:00:00Z")
        let readout = HourFormat.readout(offset: 5, anchorHour: anchor, now: anchor, calendar: Self.utcCalendar)
        #expect(!readout.isNextDay)
        #expect(readout.clockLabel == "15:00")
    }

    @Test("isNextDay compares against 'now', not anchorHour — a stale anchor from yesterday doesn't fool it")
    func comparesAgainstNowNotAnchor() {
        let anchor = Self.date("2026-07-30T10:00:00Z")
        let now = Self.date("2026-07-31T09:00:00Z")  // a day has genuinely passed since the anchor
        let readout = HourFormat.readout(offset: 0, anchorHour: anchor, now: now, calendar: Self.utcCalendar)
        #expect(readout.isNextDay)
    }

    // MARK: - voiceOverValue

    @Test("voiceOverValue for 'Now' omits the hours phrase")
    func voiceOverValueForNow() {
        let readout = HourFormat.Readout(offsetLabel: "Now", clockLabel: "18:00", isNextDay: false)
        #expect(HourFormat.voiceOverValue(readout) == "Now, 18:00")
    }

    @Test("voiceOverValue matches the TRD's own example exactly")
    func voiceOverValueMatchesTRDExample() {
        let readout = HourFormat.Readout(offsetLabel: "+3h", clockLabel: "21:00", isNextDay: true)
        #expect(HourFormat.voiceOverValue(readout) == "+3 hours, 21:00, next day")
    }

    @Test("voiceOverValue omits 'next day' when the selection stays same-day")
    func voiceOverValueOmitsNextDayWhenSameDay() {
        let readout = HourFormat.Readout(offsetLabel: "+5h", clockLabel: "15:00", isNextDay: false)
        #expect(HourFormat.voiceOverValue(readout) == "+5 hours, 15:00")
    }
}
