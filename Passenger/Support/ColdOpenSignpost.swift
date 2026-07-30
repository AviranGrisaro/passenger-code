import os

/// Brackets the TRD §7 cold-open milestone — "process start → first frame `Map`
/// accepts a pan gesture" — with a custom `os_signpost` interval, rather than
/// relying on `XCTApplicationLaunchMetric`'s generic app-launch-completion signal.
///
/// Both `ios-developer` and `ios-code-reviewer` flagged this at `trd-review`:
/// the launch metric measures Apple's own definition of "launched," which isn't
/// provably the same instant as the TRD's specific milestone. This gives
/// Instruments (or `XCTOSSignpostMetric`) something that measures exactly the
/// claimed thing, moved up in the build order to run right after C3 rather than
/// last at C11, per both reviewers' sequencing note.
enum ColdOpenSignpost {
    static let log = OSLog(subsystem: "com.avirangrisaro.passenger", category: "ColdOpen")
    static let signpostID = OSSignpostID(log: log)
    private static let name: StaticString = "ColdOpenToInteractive"

    /// Called once, as early as possible in `PassengerApp.init()`.
    static func begin() {
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
    }

    /// Called once, the first time `MapScreen`'s `Map` appears — TRD §7 defines
    /// "interactive" as the first frame in which `Map` accepts a pan gesture,
    /// and `Map` is gesture-ready from its first rendered frame (no async seed
    /// blocks it, §7's own budget table).
    @MainActor
    private static var didEnd = false

    @MainActor
    static func endIfNeeded() {
        guard !didEnd else { return }
        didEnd = true
        os_signpost(.end, log: log, name: name, signpostID: signpostID)
    }
}
