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
}
