import Foundation

/// Sequential settings migration system.
///
/// Each migration is a closure that transforms UserDefaults from version N to N+1.
/// `runIfNeeded()` executes all pending migrations in order, then stamps the new version.
enum SettingsMigration {

    /// Current schema version. Bump this and add a migration closure when changing settings format.
    static let currentVersion = 1

    /// UserDefaults key storing the last-applied schema version.
    private static let versionKey = "settingsVersion"

    /// Ordered migration closures: index 0 = v0→v1, index 1 = v1→v2, etc.
    private static let migrations: [(UserDefaults) -> Void] = [
        // v0 → v1: Initial version stamp (no-op).
        { _ in },
    ]

    /// Runs any pending migrations. Call once at app launch before accessing settings.
    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        let stored = defaults.integer(forKey: versionKey)  // 0 if never set

        guard stored < currentVersion else { return }

        for version in stored..<currentVersion {
            guard version < migrations.count else { break }
            NSLog("GestureKeys: Running settings migration v%d → v%d", version, version + 1)
            migrations[version](defaults)
        }

        defaults.set(currentVersion, forKey: versionKey)
        NSLog("GestureKeys: Settings migrated to v%d", currentVersion)
    }
}
