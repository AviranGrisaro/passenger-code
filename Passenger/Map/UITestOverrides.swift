import SwiftUI

/// C15 (TRD §11, `PAS-51` findings 1 and 4) — the rendered-verification
/// seam. Two launch-argument reads, applied once at `MapScreen`'s
/// composition root, that let a UI test force a real render at a real
/// accessibility text size and against a real fixed clock — instead of
/// standing in a source grep for a rendered check, or getting a "next day"
/// positive control that only fires when the suite happens to run after
/// local noon.
///
/// **Both default to today's behaviour when the argument is absent** — a
/// normal launch reads neither `ProcessInfo` key past this file, so it
/// behaves byte-identically to before C15 existed. Neither override is a
/// feature: `-uiTestDynamicTypeSize`/`-uiTestNow` are not documented outside
/// this file and `PassengerUITests`, same idiom as `MapScreen`'s existing
/// `-uiTestZoomedIn`/`-uiTestExposeCameraRegion` seams.
///
/// **Status as of T-081/`PAS-76` (2026-08-08): unverified, not confirmed.**
/// This seam previously propagated `.environment(\.dynamicTypeSize, …)` into
/// `SearchOverlay`'s Hour segment, clamped by its own
/// `.dynamicTypeSize(...maxDynamicTypeSize)`. That Hour segment (and its
/// sole test consumer, `SearchHourSegmentInteractionTests`'s rendered AX3/AX5
/// suite) was deleted by T-081/`PAS-76`. **No test currently passes
/// `-uiTestDynamicTypeSize` at all**, so this override seam has zero live
/// consumers — it is still applied at `MapScreen.swift:699` and remains a
/// no-op on a normal launch, same as always, but nothing exercises the
/// non-default path. A future UI test that needs it should verify the
/// propagation fresh rather than rely on this comment's history.
enum UITestOverrides {
    /// `-uiTestDynamicTypeSize <size>` — one of `DynamicTypeSize`'s own case
    /// names (`xSmall`, `small`, `medium`, `large`, `xLarge`, `xxLarge`,
    /// `xxxLarge`, `accessibility1`...`accessibility5`). `nil` when the
    /// argument is absent or unrecognized, so the caller falls back to
    /// whatever the environment already provides — never a second implicit
    /// default duplicating SwiftUI's own.
    static var dynamicTypeSize: DynamicTypeSize? {
        guard let raw = launchArgumentValue(for: "-uiTestDynamicTypeSize") else { return nil }
        switch raw {
        case "xSmall": return .xSmall
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "xLarge": return .xLarge
        case "xxLarge": return .xxLarge
        case "xxxLarge": return .xxxLarge
        case "accessibility1": return .accessibility1
        case "accessibility2": return .accessibility2
        case "accessibility3": return .accessibility3
        case "accessibility4": return .accessibility4
        case "accessibility5": return .accessibility5
        default: return nil
        }
    }

    /// `-uiTestNow <ISO-8601 instant>` (e.g. `2026-08-07T23:00:00Z`) — the
    /// single fixed clock `MapScreen` passes to both `HourFormat.readout`
    /// and `DensityStore(now:)`, in place of two independent live
    /// `Date()` calls. Returns `Date()` — real, live, unpinned — whenever
    /// the argument is absent or unparseable, exactly matching pre-C15
    /// behaviour.
    static func now() -> Date {
        guard
            let raw = launchArgumentValue(for: "-uiTestNow"),
            let parsed = ISO8601DateFormatter().date(from: raw)
        else {
            return Date()
        }
        return parsed
    }

    /// `ProcessInfo`'s launch arguments store `-flag value` as two adjacent
    /// array elements, not a `flag=value` pair — this reads the element
    /// immediately after the named flag, mirroring how Foundation/XCTest's
    /// own `-flag` launch arguments are conventionally passed.
    private static func launchArgumentValue(for flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: flag), arguments.index(after: flagIndex) < arguments.endIndex
        else {
            return nil
        }
        return arguments[arguments.index(after: flagIndex)]
    }
}
