import Foundation
import Testing

/// PAS-51 (T-032/PAS-15 F1/F2 rebuild, carried forward after Aviran's
/// 2026-08-04 founder-direct override marked T-032 `done` over an open
/// `product` REJECT — see `PROGRESS.md`'s "FOUNDER-DIRECT STUB: T-032" entry
/// that day). The rejection named two rendered-only defects in
/// `HeatModalCard`: F1 — `MapNavRow` drawing over the hour readout at
/// default text size, truncating "next day" to "…t day" when +12h crosses
/// midnight; F2 — AX5 content size mid-token wrapping the readout and the
/// "next day" pill.
///
/// F2 has no live UI-test coverage, for the same reason
/// `SearchRowGrowthGuardTests` documents: neither the
/// `-UIPreferredContentSizeCategoryName` launch argument nor `simctl ui
/// <udid> content_size accessibility-extra-extra-extra-large` actually
/// changes rendered text size on this build's Simulator runtime (confirmed
/// live during the T-038/PAS-29 QA pass — the override is stored and
/// survives a relaunch/reboot but SpringBoard itself never renders larger).
/// A UI test that sets AX5 and asserts no wrap would pass or fail by
/// environmental accident, not signal. `HeatModalCard`'s actual fix for F2
/// is structural instead — a hard ceiling via
/// `.dynamicTypeSize(...Self.maxDynamicTypeSize)` at `.accessibility3`, one
/// step below where AX5's mid-token wrap reproduced — so this asserts that
/// ceiling directly against source, same construction as
/// `SearchRowGrowthGuardTests`/`PassportAbsenceGateTests`.
///
/// F1 already has live UI coverage —
/// `HeatModalCardLayoutTests.testReadoutNeverIntersectsTheNavRowAtDefaultTextSize`
/// (`PassengerUITests/`) renders the card and asserts the readout's real
/// frame never intersects the nav row's buttons. This file adds a
/// structural backstop for F1 too, so a future edit that silently drops the
/// gap constant (e.g. reverting to a bare `.padding(.bottom, 8)`) fails fast
/// in the unit suite rather than needing another live-rendered UI test run
/// to catch.
/// **v5 update (TRD `time-slider/TRD.md` §9, `PAS-51` findings 1/4):** these
/// source-string checks are stated explicitly as a **regression backstop
/// only** — they do **not** discharge row 5b or row 6(c), both of which
/// require a rendered check. The real render checks now live in
/// `PassengerUITests/HeatModalCardDynamicTypeCeilingTests`, driven by C15's
/// `-uiTestDynamicTypeSize`/`-uiTestNow` launch-argument seam
/// (`UITestOverrides`) rather than the simulator content-size override this
/// file's own header below documents as dead on this toolchain.
@Suite("HeatModalCard — F1/F2 structural guard (PAS-51)")
struct HeatModalCardLayoutGuardTests {
    private static func sourceOfHeatModalCard() throws -> String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent("Passenger/HeatModal/HeatModalCard.swift"),
            encoding: .utf8
        )
    }

    @Test("card's dynamic type ceiling stays at .accessibility3, never reaching AX5 where F2's mid-token wrap reproduced")
    func dynamicTypeCeilingStaysAtAccessibility3() throws {
        let source = try Self.sourceOfHeatModalCard()

        #expect(
            source.contains("private static let maxDynamicTypeSize: DynamicTypeSize = .accessibility3"),
            "F2 regression guard: HeatModalCard's dynamic type ceiling must stay at .accessibility3 — raising it (or removing the cap) reopens AX5's mid-token wrap of the hour readout and the next-day pill"
        )
        #expect(
            source.contains(".dynamicTypeSize(...Self.maxDynamicTypeSize)"),
            "F2 regression guard: the ceiling constant exists but must actually be applied to `card` via .dynamicTypeSize(...Self.maxDynamicTypeSize)"
        )
    }

    @Test("card's bottom padding clears the nav row band by a fixed positive gap, never bottom: 0")
    func cardStaysAboveNavRowBand() throws {
        let source = try Self.sourceOfHeatModalCard()

        #expect(
            source.contains("private static let gapAboveNavRow: CGFloat = 16"),
            "F1 regression guard: the fixed gap above the nav row must stay a positive constant — shrinking it to 0 or removing it reopens F1's occlusion of the hour readout"
        )
        #expect(
            source.contains(".padding(.bottom, Self.navRowBandHeight + Self.gapAboveNavRow)"),
            "F1 regression guard: card must anchor its bottom padding to navRowBandHeight + gapAboveNavRow, not a bare constant like the old .padding(.bottom, 8) that put the card's bottom edge inside the nav row's own band"
        )
    }
}
