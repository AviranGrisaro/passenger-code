import Foundation
import Testing
@testable import Passenger

@Suite("DensitySnapshot boundary validation")
struct DensitySnapshotTests {
    private static func epochHour(_ iso: String) -> Int {
        Int(ISO8601DateFormatter().date(from: iso)!.timeIntervalSince1970 / 3600)
    }

    @Test("a valid row resolves to the right band at the right hour")
    func validRowResolves() {
        let rows = [DensityAPI.Row(hoodID: "florentin", hourBucket: "2026-07-30T18:00:00Z", band: 3)]
        let snapshot = DensitySnapshot(rows: rows)
        #expect(snapshot.band(for: "florentin", epochHour: Self.epochHour("2026-07-30T18:00:00Z")) == .busy)
    }

    @Test("an unknown band integer drops just that row, not the whole snapshot")
    func unknownBandDropsRow() {
        let rows = [
            DensityAPI.Row(hoodID: "florentin", hourBucket: "2026-07-30T18:00:00Z", band: 3),
            DensityAPI.Row(hoodID: "florentin", hourBucket: "2026-07-30T19:00:00Z", band: 99),
        ]
        let snapshot = DensitySnapshot(rows: rows)
        #expect(snapshot.band(for: "florentin", epochHour: Self.epochHour("2026-07-30T18:00:00Z")) == .busy)
        #expect(snapshot.band(for: "florentin", epochHour: Self.epochHour("2026-07-30T19:00:00Z")) == nil)
    }

    @Test("an unparseable timestamp drops just that row, not the whole snapshot")
    func unparseableTimestampDropsRow() {
        let rows = [
            DensityAPI.Row(hoodID: "florentin", hourBucket: "2026-07-30T18:00:00Z", band: 1),
            DensityAPI.Row(hoodID: "florentin", hourBucket: "not-a-date", band: 2),
        ]
        let snapshot = DensitySnapshot(rows: rows)
        #expect(snapshot.band(for: "florentin", epochHour: Self.epochHour("2026-07-30T18:00:00Z")) == .quiet)
    }

    @Test("a hood/hour with no row at all reads nil, never a default band")
    func missingRowIsNil() {
        #expect(DensitySnapshot.empty.band(for: "florentin", epochHour: 0) == nil)
    }
}
