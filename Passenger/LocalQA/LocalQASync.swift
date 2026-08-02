/// The sync seam (TRD §4.3) — nothing in `LocalQA/` beyond this file knows
/// whether an answer ever reaches a server.
enum SyncState: Sendable, Equatable {
    case disabled
    case online
    case offline
}

extension SyncState {
    /// The toast's confirmation copy, derived from sync state rather than
    /// hardcoded (TRD §8 D6) — so the app never claims a share that didn't
    /// happen. In Build Phase 1 `.disabled` is the only reachable case: there
    /// is no server and no eventual sync yet.
    var confirmationCopy: String {
        switch self {
        case .online: "Thanks — shared with other travelers"
        case .offline: "Saved on device — will sync once you're back online"
        // **[ASSUMPTION]** on this string's wording (D6) — `designer`'s to
        // overturn, one line.
        case .disabled: "Saved on this device."
        }
    }
}

/// Sync target for the local-QA answer queue.
protocol LocalQASyncing: Sendable {
    var state: SyncState { get }
    /// Returns the number of records accepted.
    func flush(_ records: [LocalQARecord], installID: LocalQAInstallIdentity) async -> Int
}

/// Phase 1's sync implementation (TRD §7): `state == .disabled`, accepts
/// nothing — the queue simply grows until a real backend (`local_qa_answers`,
/// held for Build Phase 2 as B1) exists to accept it.
struct DisabledLocalQASync: LocalQASyncing {
    let state: SyncState = .disabled

    func flush(_ records: [LocalQARecord], installID: LocalQAInstallIdentity) async -> Int {
        0
    }
}
