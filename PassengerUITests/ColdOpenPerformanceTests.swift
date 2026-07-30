import XCTest

/// TRD §7: verifies the cold-open budget against the TRD's own defined
/// milestone — "process start → first frame `Map` accepts a pan gesture" —
/// via the `ColdOpenToInteractive` `os_signpost` interval `ColdOpenSignpost`
/// emits (`PassengerApp.init()` → `MapScreen`'s `Map.onAppear`).
///
/// This measures the *named* milestone directly with `XCTOSSignpostMetric`,
/// rather than `XCTApplicationLaunchMetric`, which tracks Apple's own generic
/// "app finished launching" signal — a different, adjacent instant, not
/// provably the same one the TRD budgets against (both `ios-developer` and
/// `ios-code-reviewer` flagged this gap at `trd-review`). Budget: ≤2.0s
/// total-to-interactive (TRD §7's table, the two unbounded items excluded).
///
/// **Simulator run only, in this build environment.** The TRD requires
/// verification on a physical iPhone 11 / iPhone SE (2nd gen), A13 — the
/// oldest iOS-26-supported device (§7's `[ASSUMPTION]`, confirmed correct at
/// trd-review) — and this sandboxed session has no physical device or
/// Instruments UI attached to it. This test proves the signpost
/// instrumentation is wired correctly end to end and gives a simulator-side
/// number for the build report; it is not a substitute for the on-device
/// measurement `qa` still needs to run before acceptance (TRD §7's own
/// "Verification is required, not assumed" line).
final class ColdOpenPerformanceTests: XCTestCase {
    func testColdOpenToInteractiveSignpost() {
        let app = XCUIApplication()
        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(
            metrics: [XCTOSSignpostMetric(subsystem: "com.avirangrisaro.passenger", category: "ColdOpen", name: "ColdOpenToInteractive")],
            options: options
        ) {
            app.launch()
            app.terminate()
        }
    }
}
