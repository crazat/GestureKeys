import Foundation
import Sparkle

/// Singleton that manages Sparkle auto-update lifecycle.
/// Initialized once at app launch, shared with About window for manual check.
/// Gracefully disables itself if SUPublicEDKey is not configured.
final class UpdaterManager {
    static let shared = UpdaterManager()

    private(set) var controller: SPUStandardUpdaterController?

    /// Whether Sparkle is properly configured and ready.
    var isConfigured: Bool { controller != nil }

    private init() {}

    /// Call once at app startup. Starts Sparkle's automatic update checks
    /// if SUPublicEDKey is set in Info.plist.
    func startIfConfigured() {
        guard let edKey = Bundle.main.infoDictionary?["SUPublicEDKey"] as? String,
              !edKey.isEmpty else {
            NSLog("GestureKeys: Sparkle disabled — SUPublicEDKey not configured")
            return
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        NSLog("GestureKeys: Sparkle updater started")
    }

    /// Manually check for updates (called from About window).
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
