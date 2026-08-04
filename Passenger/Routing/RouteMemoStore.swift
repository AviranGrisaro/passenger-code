import Foundation

/// The 5-minute session memo, one instance for the app's lifetime, outliving
/// every `RoutePreviewModel` (TRD §4.7, A2). The memo has to survive a modal
/// dismissal — that is its entire purpose — so it cannot live in an object
/// that is torn down on dismissal.
@MainActor
@Observable
final class RouteMemoStore {
    private static let ttl: TimeInterval = 300  // 5 minutes (TRD §4.7)

    /// `[Place.ID: (RoutePreview, Date)]`, in memory. Key is `Place.id`
    /// alone — no coordinate, per TRD §3.3.
    private var entries: [Place.ID: (preview: RoutePreview, storedAt: Date)] = [:]

    /// Returns `nil` when absent OR expired. Expiry is evaluated on read, so
    /// no timer exists and a stale entry can never be observed.
    func preview(for id: Place.ID, now: Date = .now) -> RoutePreview? {
        guard let entry = entries[id] else { return nil }
        guard now.timeIntervalSince(entry.storedAt) < Self.ttl else { return nil }
        return entry.preview
    }

    /// Stores `.resolved` only. `.failed`, `.noOrigin`, `.resolving` and
    /// `.idle` are never memoised — a transient failure or a permission
    /// state must be retried on the next open, not cached for 5 minutes.
    func store(_ preview: RoutePreview, for id: Place.ID, now: Date = .now) {
        guard case .resolved = preview else { return }
        entries[id] = (preview, now)
    }

    /// The only invalidation. Called on `scenePhase == .background` — there
    /// is deliberately no per-entry eviction API, since nothing in this
    /// feature knows better than the TTL when a route went stale.
    func clearAll() {
        entries.removeAll()
    }
}
