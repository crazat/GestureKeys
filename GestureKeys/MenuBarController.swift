import AppKit

/// Manages the menu bar status item and dropdown menu.
final class MenuBarController: NSObject, NSMenuDelegate {

    enum EngineState {
        case active
        case disabled
        case noPermission
    }

    private var statusItem: NSStatusItem?
    private let engine: GestureEngine
    private var isEnabled: Bool
    private var permissionTimer: Timer?
    private var pauseTimer: Timer?
    private var pauseEndTime: Date?

    init(engine: GestureEngine) {
        self.engine = engine
        self.isEnabled = UserDefaults.standard.object(forKey: "engineEnabled") as? Bool ?? true
        super.init()
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
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)

        let pauseMenu = NSMenu()
        for minutes in [15, 30, 60] {
            let item = NSMenuItem(
                title: "\(minutes)분",
                action: #selector(pauseForDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = minutes
            pauseMenu.addItem(item)
        }
        let pauseItem = NSMenuItem(title: "일시 정지", action: nil, keyEquivalent: "")
        pauseItem.submenu = pauseMenu
        menu.addItem(pauseItem)

        let resumeItem = NSMenuItem(
            title: "일시 정지 취소",
            action: #selector(cancelPause(_:)),
            keyEquivalent: ""
        )
        resumeItem.target = self
        menu.addItem(resumeItem)

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

        let statsItem = NSMenuItem(
            title: "통계...",
            action: #selector(openStats(_:)),
            keyEquivalent: ""
        )
        statsItem.target = self
        menu.addItem(statsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "GestureKeys에 관하여",
            action: #selector(openAbout(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "GestureKeys 종료",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        item.menu = menu
        statusItem = item

        // Check initial permission state and enabled state
        if !AXIsProcessTrusted() {
            updateIcon(state: .noPermission)
            if isEnabled { startPermissionPolling() }
        } else if isEnabled {
            updateIcon(state: .active)
        } else {
            updateIcon(state: .disabled)
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
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleEngineRestored),
            name: GestureEngine.eventTapRestoredNotification, object: nil
        )
    }

    @objc private func handleEngineIssue() {
        updateIcon(state: .noPermission)
    }

    @objc private func handleEngineRestored() {
        if isEnabled {
            updateIcon(state: .active)
        }
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
        guard permissionTimer == nil else { return }
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
            }
        }
    }

    // MARK: - Actions

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        // Cancel any active pause when manually toggling
        pauseTimer?.invalidate()
        pauseTimer = nil
        pauseEndTime = nil

        isEnabled.toggle()
        UserDefaults.standard.set(isEnabled, forKey: "engineEnabled")
        sender.state = isEnabled ? .on : .off

        if isEnabled {
            if AXIsProcessTrusted() {
                engine.start()
                updateIcon(state: .active)
            } else {
                updateIcon(state: .noPermission)
                startPermissionPolling()
            }
        } else {
            permissionTimer?.invalidate()
            permissionTimer = nil
            engine.stop()
            updateIcon(state: .disabled)
        }
    }

    @objc private func pauseForDuration(_ sender: NSMenuItem) {
        let minutes = sender.tag
        guard minutes > 0 else { return }

        // Stop engine
        engine.stop()
        updateIcon(state: .disabled)

        // Schedule resume
        pauseEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.pauseTimer = nil
            self.pauseEndTime = nil
            if self.isEnabled && AXIsProcessTrusted() {
                self.engine.start()
                self.updateIcon(state: .active)
            }
        }

        NSLog("GestureKeys: Paused for %d minutes", minutes)
    }

    @objc private func cancelPause(_ sender: NSMenuItem) {
        pauseTimer?.invalidate()
        pauseTimer = nil
        pauseEndTime = nil
        if isEnabled && AXIsProcessTrusted() {
            engine.start()
            updateIcon(state: .active)
        }
        NSLog("GestureKeys: Pause cancelled by user")
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

    @objc private func openStats(_ sender: NSMenuItem) {
        StatsWindowController.shared.show()
    }

    @objc private func openAbout(_ sender: NSMenuItem) {
        AboutWindowController.shared.show()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        permissionTimer?.invalidate()
        pauseTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        engine.stop()
        NSApp.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Grey out pause submenu when engine is disabled or already paused
        if let pauseItem = menu.items.first(where: { $0.title == "일시 정지" }) {
            pauseItem.isEnabled = isEnabled && pauseEndTime == nil
        }
        // Show/hide resume item based on pause state
        if let resumeItem = menu.items.first(where: { $0.title == "일시 정지 취소" }) {
            resumeItem.isHidden = pauseEndTime == nil
        }

        if let endTime = pauseEndTime {
            let remaining = Int(endTime.timeIntervalSinceNow)
            if remaining > 0 {
                statusItem?.button?.toolTip = "GestureKeys — 일시 정지 중 (\(remaining / 60)분 \(remaining % 60)초 남음)"
            } else {
                statusItem?.button?.toolTip = "GestureKeys — 비활성화됨"
            }
        } else if isEnabled {
            let todayCount = GestureStats.shared.totalFires(days: 1)
            let activeCount = GestureConfig.all.filter { GestureConfig.shared.uiIsEnabled($0.id) }.count
            let recent = GestureStats.shared.recentGestureNames()
            var tip = "GestureKeys — 오늘 \(todayCount)회 사용 · \(activeCount)개 활성"
            if !recent.isEmpty {
                tip += "\n최근: \(recent.prefix(3).joined(separator: ", "))"
            }
            statusItem?.button?.toolTip = tip
        } else {
            statusItem?.button?.toolTip = "GestureKeys — 비활성화됨"
        }
    }
}
