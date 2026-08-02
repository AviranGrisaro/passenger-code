import Foundation

/// One per-install UUID, generated on first write into `local-qa.json` and
/// persisted there. **Deliberately NOT `app_installs.install_id`** — see TRD
/// §8 D9. Named `LocalQAInstallIdentity` rather than `InstallIdentity`
/// precisely so a future edit cannot quietly point this at the analytics id
/// under the impression it's consolidating a duplicate; unifying the two
/// must go through D9 first. Not the IDFV, not the IDFA, not the Keychain —
/// a file in Application Support dies with the app, which is exactly the
/// intended lifetime (§3.3).
struct LocalQAInstallIdentity: Codable, Sendable, Equatable {
    let value: UUID

    static func generate() -> LocalQAInstallIdentity {
        LocalQAInstallIdentity(value: UUID())
    }
}
