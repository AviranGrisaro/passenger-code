import os

/// Brackets the T-032 repaint milestone (TRD §4.7): *"`selectedHour` written
/// → every Hood's band resolved for the new hour."* Mirrors
/// `Support/ColdOpenSignpost.swift` exactly, with one difference this signal
/// requires that signpost didn't: `HourRepaint` fires many times per session
/// (once per real hour change), not once, so each cycle gets its own
/// `OSSignpostID` rather than a single fixed one — `endIfPending()` is a
/// no-op when nothing is pending, which is what makes it safe to call
/// unconditionally from `MapScreen`'s fill-resolution pass.
///
/// Honest scope, stated the way T-031 stated its own: this excludes
/// MapKit's own frame commit, which app code cannot observe. The <400ms
/// budget is held structurally first (no code path fetches on an hour
/// change) and measured second.
enum HeatRepaintSignpost {
    static let log = OSLog(subsystem: "com.avirangrisaro.passenger", category: "HeatRepaint")
    private static let name: StaticString = "HourRepaint"

    @MainActor private static var pendingID: OSSignpostID?

    /// Called on a real hour change, from either writer (`HourSlider` or
    /// `EdgeHourZone`) — never on every render.
    @MainActor
    static func begin() {
        let id = OSSignpostID(log: log)
        pendingID = id
        os_signpost(.begin, log: log, name: name, signpostID: id)
    }

    /// Called immediately after `HeatComposition.fills(...)` returns. A
    /// no-op if `begin()` was never called for this cycle.
    @MainActor
    static func endIfPending() {
        guard let id = pendingID else { return }
        pendingID = nil
        os_signpost(.end, log: log, name: name, signpostID: id)
    }
}
