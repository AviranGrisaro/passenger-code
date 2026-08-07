import Foundation
import Testing

/// T-078/`PAS-60` reopened — replaces `HeatModalCardLayoutGuardTests`, which
/// grepped the now-deleted `HeatModalCard.swift`. `PAS-51` finding 2's fix
/// (a hard dynamic-type ceiling at `.accessibility3`, one step below where
/// AX5's mid-token wrap reproduced) still applies — it's just implemented on
/// `SearchOverlay`'s Hour segment now (`nav-row-v2-redesign.md` §1) instead
/// of a standalone card. This is a **regression backstop only**, same
/// caveat the deleted file carried: it does not discharge a rendered
/// AX3/AX5 check on its own (see `SearchHourSegmentInteractionTests`'s
/// header for what that follow-up still owes).
@Suite("SearchOverlay Hour segment — dynamic type ceiling guard (PAS-51 carried forward)")
struct SearchOverlayHourGuardTests {
    private static func sourceOfSearchOverlay() throws -> String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent("Passenger/SearchSheet/SearchOverlay.swift"),
            encoding: .utf8
        )
    }

    @Test("Hour segment's dynamic type ceiling stays at .accessibility3, never reaching AX5 where the original F2 mid-token wrap reproduced")
    func dynamicTypeCeilingStaysAtAccessibility3() throws {
        let source = try Self.sourceOfSearchOverlay()

        #expect(
            source.contains("private static let maxDynamicTypeSize: DynamicTypeSize = .accessibility3"),
            "F2 regression guard: SearchOverlay's Hour segment dynamic type ceiling must stay at .accessibility3 — raising it (or removing the cap) reopens AX5's mid-token wrap of the hour readout and the next-day pill"
        )
        #expect(
            source.contains(".dynamicTypeSize(...Self.maxDynamicTypeSize)"),
            "F2 regression guard: the ceiling constant exists but must actually be applied to the Hour segment's content via .dynamicTypeSize(...Self.maxDynamicTypeSize)"
        )
    }
}
