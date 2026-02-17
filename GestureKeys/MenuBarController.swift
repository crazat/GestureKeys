import AppKit

/// Manages the menu bar status item and dropdown menu.
final class MenuBarController {

    enum EngineState {
        case active
        case disabled
        case noPermission
    }

    private var statusItem: NSStatusItem?
    private let engine: GestureEngine
    private var isEnabled = true
    private var permissionTimer: Timer?

    init(engine: GestureEngine) {
        self.engine = engine
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "hand.raised.fingers.spread",
            accessibilityDescription: "GestureKeys"
        )

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "활성화",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = .on
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "설정...",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let monitorItem = NSMenuItem(
            title: "제스처 테스트...",
            action: #selector(openMonitor(_:)),
            keyEquivalent: ""
        )
        monitorItem.target = self
        menu.addItem(monitorItem)

        let cheatSheetItem = NSMenuItem(
            title: "바로가기...",
            action: #selector(openCheatSheet(_:)),
            keyEquivalent: ""
        )
        cheatSheetItem.target = self
        menu.addItem(cheatSheetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "GestureKeys 종료",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item

        // Check initial permission state
        if !AXIsProcessTrusted() {
            updateIcon(state: .noPermission)
            startPermissionPolling()
        } else {
            updateIcon(state: .active)
        }

        // Observe engine health for icon updates
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleEngineIssue),
            name: GestureEngine.eventTapFailedNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleEngineIssue),
            name: GestureEngine.permissionIssueNotification, object: nil
        )
    }

    @objc private func handleEngineIssue() {
        updateIcon(state: .noPermission)
    }

    func updateIcon(state: EngineState) {
        let symbolName: String
        switch state {
        case .active:
            symbolName = "hand.raised.fingers.spread"
        case .disabled:
            symbolName = "hand.raised.slash"
        case .noPermission:
            symbolName = "exclamationmark.triangle"
        }
        statusItem?.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "GestureKeys"
        )
    }

    // MARK: - Permission Polling

    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                if self.isEnabled {
                    self.engine.start()
                    self.updateIcon(state: .active)
                } else {
                    self.updateIcon(state: .disabled)
                }
                NSLog("GestureKeys: Accessibility permission granted, engine started")
            }
        }
    }

    // MARK: - Actions

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off

        if isEnabled {
            engine.start()
            updateIcon(state: .active)
        } else {
            engine.stop()
            updateIcon(state: .disabled)
        }
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        SettingsWindowController.shared.show()
    }

    @objc private func openMonitor(_ sender: NSMenuItem) {
        GestureMonitorWindowController.shared.show()
    }

    @objc private func openCheatSheet(_ sender: NSMenuItem) {
        CheatSheetWindowController.shared.show()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        permissionTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        engine.stop()
        NSApp.terminate(nil)
    }
}
