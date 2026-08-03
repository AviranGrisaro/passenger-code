import Foundation

/// Pure offset → label formatting (TRD §3.2, §4.4). Injectable clock and
/// calendar, so every string is unit-testable with no simulator and no
/// fixed timezone — a midnight crossing is just another `Date`.
enum HourFormat {
    struct Readout: Equatable, Sendable {
        /// `"Now"` for offset 0, `"+\(offset)h"` otherwise — the primary
        /// channel, never a bare clock time (§3.2).
        let offsetLabel: String
        /// `"21:00"` — P1 surface, always computed (§3.2).
        let clockLabel: String
        let isNextDay: Bool
    }

    /// `anchorHour` (UTC hour floor) + `offset × 3600s` = the selected
    /// absolute instant; everything below reads off that instant in the
    /// **injected** calendar, never `.current` directly, so this stays pure
    /// (§3.2).
    static func readout(offset: Int, anchorHour: Date, now: Date, calendar: Calendar) -> Readout {
        let selectedInstant = anchorHour.addingTimeInterval(Double(offset) * 3600)
        let offsetLabel = offset == 0 ? "Now" : "+\(offset)h"
        let clockLabel = Self.clockLabel(for: selectedInstant, calendar: calendar)
        // Compared against the real clock (`now`), not `anchorHour` — a
        // selection can cross midnight in either direction relative to when
        // the control was opened (§3.2).
        let isNextDay = !calendar.isDate(selectedInstant, inSameDayAs: now)
        return Readout(offsetLabel: offsetLabel, clockLabel: clockLabel, isNextDay: isNextDay)
    }

    /// `"+3 hours, 21:00, next day"` — VoiceOver's adjustable-action value
    /// (§4.4). Deliberately hand-assembled rather than routed through
    /// `Date.FormatStyle`'s own accessibility phrasing, so the "next day"
    /// qualifier and the offset-first ordering are both explicit and
    /// testable.
    static func voiceOverValue(_ readout: Readout) -> String {
        var parts: [String] = []
        if readout.offsetLabel == "Now" {
            parts.append("Now")
        } else {
            let digits = readout.offsetLabel.trimmingCharacters(in: CharacterSet(charactersIn: "+h"))
            parts.append("+\(digits) hours")
        }
        parts.append(readout.clockLabel)
        if readout.isNextDay {
            parts.append("next day")
        }
        return parts.joined(separator: ", ")
    }

    /// Manual `HH:mm` formatting off the injected calendar's own time zone
    /// — deliberately not locale-dependent `Date.FormatStyle`, which would
    /// render 12-hour time in some locales and make "21:00" untestable
    /// against a fixed expectation.
    private static func clockLabel(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }
}
