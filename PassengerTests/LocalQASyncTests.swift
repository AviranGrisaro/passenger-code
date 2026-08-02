import Testing
@testable import Passenger

/// tourist-trap-flag TRD §8 D6: confirmation copy is a pure mapping off
/// `SyncState`, never hardcoded.
@Suite("SyncState.confirmationCopy")
struct LocalQASyncTests {
    @Test("each sync state maps to its own confirmation string, per D6")
    func confirmationCopyMapping() {
        #expect(SyncState.online.confirmationCopy == "Thanks — shared with other travelers")
        #expect(SyncState.offline.confirmationCopy == "Saved on device — will sync once you're back online")
        #expect(SyncState.disabled.confirmationCopy == "Saved on this device.")
    }

    @Test("the three confirmation strings are distinct")
    func allThreeAreDistinct() {
        let strings = Set([SyncState.online, .offline, .disabled].map(\.confirmationCopy))
        #expect(strings.count == 3)
    }

    @Test("DisabledLocalQASync reports .disabled and accepts nothing (Phase 1, TRD §7)")
    func disabledSyncAcceptsNothing() async {
        let sync = DisabledLocalQASync()
        #expect(sync.state == .disabled)
        let accepted = await sync.flush(
            [LocalQARecord(placeID: "p", answer: true, answeredAtHour: .now)],
            installID: .generate()
        )
        #expect(accepted == 0)
    }
}
