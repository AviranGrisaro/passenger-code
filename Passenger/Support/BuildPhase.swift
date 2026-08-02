/// `BOARD.md`'s "V1 Build Phases" section, and `hood-place-detail/TRD.md` §3.4.1
/// (§8 D10). Build Phase 1 ships the iOS app 100% client-side, no backend —
/// so `PlaceCatalog.load()` loads the bundled seed and attempts no fetch.
///
/// Flipping this one constant to `false` is the *entire* Build-Phase-2 wiring
/// change for this feature (TRD §7) — nothing else moves. It is a runtime
/// constant, not `#if`, so both branches of `PlaceCatalog.load()` stay
/// compiled, type-checked and reviewable through Phase 1 instead of rotting
/// behind a compilation flag (TRD §3.4.1).
///
/// Deliberately **not** derived from `AppConfig.supabase == nil` (an absent
/// `SupabaseConfig.plist`) — that is a build-machine property, not a design
/// decision, and it would make the Phase-1 data source different on a
/// machine that happens to have credentials versus one that doesn't. This
/// constant makes the source identical everywhere.
enum BuildPhase {
    static let seedIsAuthoritative = true

    /// places-been-saved TRD §3.3, D2 — a second constant, not a reuse of
    /// `seedIsAuthoritative`, because it names a different axis: that one is
    /// *bundled data vs. the server*, this is *fixture vs. a device sensor*.
    /// Collapsing them would make the Phase-2 flip turn on a real dwell
    /// detector that does not exist yet. `VisitedPlacesStore` reads a bundled
    /// fixture (`BundledVisitSource`) while this is `true`; Phase 2 swaps in
    /// a `VisitSourcing` conformer backed by the shared detector and flips
    /// this to `false` — no other code in this feature moves.
    static let visitsAreSeeded = true

    /// `live-events-overlay/TRD.md` §7, §8 D9. A second, separate constant —
    /// not a reuse of `seedIsAuthoritative` — because places/density go live
    /// in Build Phase 2 while events go live one phase later, in Build
    /// Phase 3 (`BOARD.md`). One shared constant would fire the events fetch
    /// a phase early, against an `events_public` view that doesn't exist yet.
    static let eventSeedIsAuthoritative = true
}
