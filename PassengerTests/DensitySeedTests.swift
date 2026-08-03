import Foundation
import Testing
@testable import Passenger

/// TRD §3.4, §10, C10: covers the seed's relative→absolute synthesis and
/// the authoring rule that keeps the differs-across-hours check (§9 row 2a)
/// and `qa`'s perceptual repaint check from passing vacuously.
@Suite("DensitySeed")
struct DensitySeedTests {
    private static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    @Test("rows(anchorHour:) is correct at any launch date — relative offsets, not stale absolute timestamps")
    func rowsAreRelativeToTheLiveAnchor() {
        let anchor = Self.date("2026-07-30T18:00:00Z")
        let rows = DensitySeed.rows(anchorHour: anchor)

        let florentinAtOffset0 = rows.first { $0.hoodID == "florentin" && $0.hourBucket == Self.iso(anchor) }
        #expect(florentinAtOffset0?.band == 2)

        // Re-anchored a day later: same relative shape, different absolute hours.
        let laterAnchor = anchor.addingTimeInterval(24 * 3600)
        let laterRows = DensitySeed.rows(anchorHour: laterAnchor)
        let florentinLater = laterRows.first { $0.hoodID == "florentin" && $0.hourBucket == Self.iso(laterAnchor) }
        #expect(florentinLater?.band == 2)
        #expect(florentinAtOffset0?.hourBucket != florentinLater?.hourBucket)
    }

    @Test("a null entry produces no row for that hood/offset — exercises req 2's silent-empty bullet")
    func nullEntryProducesNoRow() {
        let anchor = Self.date("2026-07-30T18:00:00Z")
        let rows = DensitySeed.rows(anchorHour: anchor)
        let oldNorthOffset3Bucket = Self.iso(anchor.addingTimeInterval(3 * 3600))
        #expect(!rows.contains { $0.hoodID == "old-north" && $0.hourBucket == oldNorthOffset3Bucket })
    }

    @Test("a missing bundled resource yields no rows, never a crash")
    func missingResourceYieldsNoRows() {
        let rows = DensitySeed.rows(anchorHour: Self.date("2026-07-30T18:00:00Z"), resourceName: "does-not-exist")
        #expect(rows.isEmpty)
    }

    @Test("authoring rule: at least 3 Hoods change band across at least 4 adjacent hour pairs")
    func authoringRuleHoldsForVariation() {
        let anchor = Self.date("2026-07-30T00:00:00Z")
        let rows = DensitySeed.rows(anchorHour: anchor)
        let byHood = Dictionary(grouping: rows, by: \.hoodID)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var hoodsWithEnoughVariation = 0
        for (_, hoodRows) in byHood {
            let bandsByOffset = Dictionary(uniqueKeysWithValues: hoodRows.compactMap { row -> (Int, Int)? in
                guard let date = formatter.date(from: row.hourBucket) else { return nil }
                let offset = Int(date.timeIntervalSince1970 / 3600) - Int(anchor.timeIntervalSince1970 / 3600)
                return (offset, row.band)
            })
            var transitions = 0
            for offset in 0..<12 {
                guard let a = bandsByOffset[offset], let b = bandsByOffset[offset + 1] else { continue }
                if a != b { transitions += 1 }
            }
            if transitions >= 4 { hoodsWithEnoughVariation += 1 }
        }

        #expect(hoodsWithEnoughVariation >= 3)
    }

    @Test("authoring rule: at least one Hood has a null hour")
    func authoringRuleHoldsForANullHour() {
        let anchor = Self.date("2026-07-30T00:00:00Z")
        let rows = DensitySeed.rows(anchorHour: anchor)
        // 5 hoods × 13 offsets would be 65 rows with zero nulls; fewer than
        // that proves at least one offset was dropped as `null`.
        #expect(rows.count < 5 * 13)
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
