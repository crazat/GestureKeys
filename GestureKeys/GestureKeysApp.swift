import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let engine = GestureEngine()
    private var menuBarController: MenuBarController?
    private var accessibilityTimer: Timer?

    /// Strong reference to prevent ARC deallocation (NSApp.delegate is weak)
    private static var keepAlive: AppDelegate?

    /// UserDefaults key tracking whether accessibility was previously granted.
    /// Used to detect stale permission after rebuild/update.
    private static let wasAccessibilityGrantedKey = "wasAccessibilityGranted"

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        keepAlive = delegate
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashReporter.install()
        SettingsMigration.runIfNeeded()

        // If a stable copy exists in ~/Applications and we're running from
        // somewhere else (DerivedData, .build, etc.), relaunch from the
        // stable copy so SMAppService registers the correct path.
        if let bundlePath = Bundle.main.bundlePath as NSString? {
            let installDir = (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
            let stablePath = (installDir as NSString).appendingPathComponent("GestureKeys.app")
            if !bundlePath.hasPrefix(installDir),
               FileManager.default.fileExists(atPath: stablePath) {
                NSLog("GestureKeys: Running from non-standard path, relaunching from %@", stablePath)
                NSWorkspace.shared.openApplication(
                    at: URL(fileURLWithPath: stablePath),
                    configuration: NSWorkspace.OpenConfiguration()
                )
                NSApp.terminate(nil)
                return
            }
        }

        NSLog("GestureKeys: App launched from %@", Bundle.main.bundlePath)

        menuBarController = MenuBarController(engine: engine)
        menuBarController?.setup()

        // Show onboarding on first launch
        OnboardingWindowController.shared.showIfNeeded()
        CrashReporter.checkForPreviousCrash()

        // Observe engine health notifications (S2, S3)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleEventTapFailed),
            name: GestureEngine.eventTapFailedNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePermissionIssue),
            name: GestureEngine.permissionIssueNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleNoDevices),
            name: GestureEngine.noDevicesNotification, object: nil
        )

        // Respect persisted enabled/disabled state from menu bar toggle
        let engineEnabled = UserDefaults.standard.object(forKey: "engineEnabled") as? Bool ?? true
        guard engineEnabled else {
            NSLog("GestureKeys: Engine disabled by user — skipping start")
            return
        }

        // Use AXIsProcessTrustedWithOptions to trigger the system prompt
        // if accessibility is not yet granted.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        NSLog("GestureKeys: AXIsProcessTrusted = %d", trusted ? 1 : 0)
        if trusted {
            UserDefaults.standard.set(true, forKey: Self.wasAccessibilityGrantedKey)
            engine.start()
        } else {
            let wasGranted = UserDefaults.standard.bool(forKey: Self.wasAccessibilityGrantedKey)
            if wasGranted {
                // Permission was previously granted but now revoked — likely a rebuild/update
                showStalePermissionAlert()
            }
            // System prompt already triggered by AXIsProcessTrustedWithOptions above
            startAccessibilityPolling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        engine.stop()
        GestureStats.shared.flushIfNeeded()
    }

    // MARK: - Accessibility

    /// Poll every 1 second until accessibility permission is granted, then start engine.
    private func startAccessibilityPolling() {
        NSLog("GestureKeys: Waiting for accessibility permission...")
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.accessibilityTimer = nil
                NSLog("GestureKeys: Accessibility permission granted")
                UserDefaults.standard.set(true, forKey: AppDelegate.wasAccessibilityGrantedKey)
                self?.engine.start()
                self?.menuBarController?.updateIcon(state: .active)
            }
        }
    }

    /// S2: CGEventTap creation failed — click gestures won't work.
    @objc private func handleEventTapFailed() {
        NSLog("GestureKeys: EventTap creation failed — showing alert")
        menuBarController?.updateIcon(state: .noPermission)

        let alert = NSAlert()
        alert.messageText = "클릭 제스처를 사용할 수 없습니다"
        alert.informativeText = "CGEventTap 생성에 실패했습니다.\n접근성 권한을 확인하고, GestureKeys를 끄고 → 다시 켜주세요."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "확인")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Self.openAccessibilitySettings()
        }
    }

    /// S3: EventTap repeatedly disabled — permission likely stale after rebuild.
    @objc private func handlePermissionIssue() {
        NSLog("GestureKeys: Permission issue detected — showing recovery alert")
        menuBarController?.updateIcon(state: .noPermission)

        let alert = NSAlert()
        alert.messageText = "접근성 권한 재설정이 필요합니다"
        alert.informativeText = "앱이 재빌드되어 접근성 권한이 무효화된 것 같습니다.\n시스템 설정에서 GestureKeys를 끄고 → 다시 켜주세요."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "확인")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Self.openAccessibilitySettings()
        }
    }

    /// No multitouch devices found — trackpad may be disconnected or unsupported.
    @objc private func handleNoDevices() {
        NSLog("GestureKeys: No multitouch devices — showing alert")
        let alert = NSAlert()
        alert.messageText = "트랙패드를 찾을 수 없습니다"
        alert.informativeText = "멀티터치 장치가 감지되지 않았습니다.\n외장 트랙패드를 사용하는 경우 연결을 확인해주세요.\n앱이 백그라운드에서 5초마다 장치를 다시 확인합니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    /// First-time accessibility request — user has never granted permission.
    private func showAccessibilityAlert() {
        menuBarController?.updateIcon(state: .noPermission)

        let alert = NSAlert()
        alert.messageText = "접근성 권한이 필요합니다"
        alert.informativeText = "GestureKeys가 트랙패드 제스처를 인식하려면 접근성 권한이 필요합니다.\n시스템 설정에서 GestureKeys를 허용해주세요."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Self.openAccessibilitySettings()
        }
    }

    /// Stale permission — was previously granted but revoked (rebuild/update changed binary hash).
    /// Shows a specific alert telling the user to toggle off → on, not just "allow".
    private func showStalePermissionAlert() {
        NSLog("GestureKeys: Stale accessibility permission detected (was granted before)")
        menuBarController?.updateIcon(state: .noPermission)

        let alert = NSAlert()
        alert.messageText = "접근성 권한 재설정이 필요합니다"
        alert.informativeText = """
            앱이 업데이트되어 기존 접근성 권한이 무효화되었습니다.

            시스템 설정 → 손쉬운 사용에서:
            1. GestureKeys를 끄고
            2. 다시 켜주세요

            권한이 복원되면 자동으로 시작됩니다.
            """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Self.openAccessibilitySettings()
        }
    }

    /// Opens System Settings to the Accessibility privacy pane.
    private static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
