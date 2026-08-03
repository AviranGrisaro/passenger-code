import Foundation
import Testing
@testable import Passenger

/// search-quick-filters TRD §9 row 8(c), §11 C13 — Dynamic Type growth,
/// verified structurally rather than via a live simulator content-size
/// override.
///
/// During the T-038/PAS-29 QA pass, both standard mechanisms for forcing the
/// largest accessibility content size in a live UI test were tried and
/// neither took visible effect on this build's Simulator runtime: the
/// `-UIPreferredContentSizeCategoryName` launch argument, and `xcrun simctl
/// ui <udid> content_size accessibility-extra-extra-extra-large` (confirmed
/// stored by its own getter, survived an app relaunch and a full simulator
/// reboot, and still didn't change rendered text size anywhere — confirmed
/// by screenshotting the plain SpringBoard home screen, which stayed at
/// default text size). That's a simulator/tooling limitation, not a
/// Passenger behavior, so a UI test asserting row growth against a content
/// size that never actually applied would pass or fail by environmental
/// accident rather than signal — the same class of problem L-010 names for
/// existing flakes, applied here before shipping a new one.
///
/// TRD §4.8's own stated mechanism for growth is structural, not
/// runtime-dependent, and is checkable directly against the source: "no
/// `.lineLimit` anywhere ... `.fixedSize(horizontal: false, vertical: true)`
/// on every text run." That's what this file asserts. Same construction as
/// `PassportAbsenceGateTests`/`SearchStructuralGuardTests`: reads the actual
/// Swift source via `#filePath` and asserts on content directly.
@Suite("Search — row growth structural guard (TRD §9 row 8c, §11 C13)")
struct SearchRowGrowthGuardTests {
    private static func sourceOf(_ relativePath: String) throws -> String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile.deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    @Test("SearchResultRow has no .lineLimit and every Text run is .fixedSize(horizontal: false, vertical: true)")
    func searchResultRowGrowsRatherThanTruncates() throws {
        let source = try Self.sourceOf("Passenger/SearchSheet/SearchResultRow.swift")

        #expect(!source.contains(".lineLimit("), "SearchResultRow must never cap its own text — growth, not truncation, is the requirement")

        let textRunCount = source.components(separatedBy: "Text(").count - 1
        let fixedSizeCount = source.components(separatedBy: ".fixedSize(horizontal: false, vertical: true)").count - 1
        #expect(textRunCount >= 2, "expected at least the two documented Text runs (name + secondary line)")
        #expect(
            fixedSizeCount == textRunCount,
            "every Text run in SearchResultRow must carry .fixedSize(horizontal: false, vertical: true) — found \(textRunCount) Text( call(s) but \(fixedSizeCount) matching .fixedSize modifier(s)"
        )
    }

    @Test("no file in the search feature caps its own text with .lineLimit")
    func noSearchViewCapsTextWithLineLimit() throws {
        let files = [
            "Passenger/SearchSheet/SearchResultRow.swift",
            "Passenger/SearchSheet/SearchFieldRow.swift",
            "Passenger/SearchSheet/CategoryChipRow.swift",
            "Passenger/SearchSheet/SearchEmptyStates.swift",
            "Passenger/SearchSheet/SearchOverlay.swift",
        ]
        for relativePath in files {
            let source = try Self.sourceOf(relativePath)
            #expect(!source.contains(".lineLimit("), "\(relativePath) must not cap its own text (PRD req 8 bullet 3)")
        }
    }
}
