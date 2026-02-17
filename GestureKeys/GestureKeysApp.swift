import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let engine = GestureEngine()
    private var menuBarController: MenuBarController?
    private var accessibilityTimer: Timer?

    /// Strong reference to prevent ARC deallocation (NSApp.delegate is weak)
    private static var keepAlive: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        keepAlive = delegate
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("GestureKeys: App launched")

        menuBarController = MenuBarController(engine: engine)
        menuBarController?.setup()

        // Show onboarding on first launch
        OnboardingWindowController.shared.showIfNeeded()

        // Observe engine health notifications (S2, S3)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleEventTapFailed),
            name: GestureEngine.eventTapFailedNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePermissionIssue),
            name: GestureEngine.permissionIssueNotification, object: nil
        )

        let trusted = AXIsProcessTrusted()
        NSLog("GestureKeys: AXIsProcessTrusted = %d", trusted ? 1 : 0)
        if trusted {
            engine.start()
        } else {
            showAccessibilityAlert()
            startAccessibilityPolling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        engine.stop()
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
                self?.engine.start()
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
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
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
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "접근성 권한이 필요합니다"
        alert.informativeText = "GestureKeys가 트랙패드 제스처를 인식하려면 접근성 권한이 필요합니다.\n시스템 설정에서 GestureKeys를 허용해주세요."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
