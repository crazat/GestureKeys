import Foundation
import ServiceManagement

/// Manages "launch at login" registration via SMAppService (macOS 13+).
enum LaunchAtLoginHelper {

    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Enable or disable launch at login.
    /// Logs errors but does not throw — UI should re-read `isEnabled` to confirm.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("GestureKeys: Launch at login error: %@", error.localizedDescription)
        }
    }
}
