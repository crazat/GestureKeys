import Foundation
import AppKit
import CoreGraphics

/// Synthesizes keyboard shortcuts and app actions.
enum KeySynthesizer {

    // MARK: - Action Enum

    /// All available actions that can be mapped to gestures.
    enum Action: String, CaseIterable, Identifiable {
        case cmdW = "cmdW"
        case cmdT = "cmdT"
        case cmdR = "cmdR"
        case prevTab = "prevTab"
        case nextTab = "nextTab"
        case newWindow = "newWindow"
        case minimize = "minimize"
        case undo = "undo"
        case redo = "redo"
        case toggleFullscreen = "toggleFullscreen"
        case spotlight = "spotlight"
        case find = "find"
        case back = "back"
        case forward = "forward"
        case addressBar = "addressBar"
        case lockScreen = "lockScreen"
        case copy = "copy"
        case paste = "paste"
        case cut = "cut"
        case screenshot = "screenshot"
        case selectAll = "selectAll"
        case screenCapture = "screenCapture"
        case volumeUp = "volumeUp"
        case volumeDown = "volumeDown"
        case save = "save"
        case pageTop = "pageTop"
        case pageBottom = "pageBottom"
        case brightnessUp = "brightnessUp"
        case brightnessDown = "brightnessDown"
        case playPause = "playPause"
        case forceQuit = "forceQuit"
        case hideApp = "hideApp"
        case terminateApp = "terminateApp"
        case sleepDisplay = "sleepDisplay"
        case kbBrightnessUp = "kbBrightnessUp"
        case kbBrightnessDown = "kbBrightnessDown"
        case shortcut = "shortcut"
        case custom = "custom"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .cmdW: return "탭 닫기 (⌘W)"
            case .cmdT: return "새 탭 (⌘T)"
            case .cmdR: return "새로고침 (⌘R)"
            case .prevTab: return "이전 탭 (⇧⌘[)"
            case .nextTab: return "다음 탭 (⇧⌘])"
            case .newWindow: return "새 창 (⌘N)"
            case .minimize: return "최소화 (⌘M)"
            case .undo: return "실행 취소 (⌘Z)"
            case .redo: return "다시 실행 (⇧⌘Z)"
            case .toggleFullscreen: return "전체화면 (⌃⌘F)"
            case .spotlight: return "Spotlight (⌘Space)"
            case .find: return "검색 (⌘F)"
            case .back: return "뒤로가기 (⌘[)"
            case .forward: return "앞으로가기 (⌘])"
            case .addressBar: return "주소창 (⌘L)"
            case .lockScreen: return "잠금화면 (⌃⌘Q)"
            case .copy: return "복사 (⌘C)"
            case .paste: return "붙여넣기 (⌘V)"
            case .cut: return "잘라내기 (⌘X)"
            case .screenshot: return "스크린샷 (⇧⌘4)"
            case .selectAll: return "전체 선택 (⌘A)"
            case .screenCapture: return "화면 캡처 (⇧⌘5)"
            case .volumeUp: return "볼륨 증가"
            case .volumeDown: return "볼륨 감소"
            case .save: return "저장 (⌘S)"
            case .pageTop: return "페이지 상단 (⌘↑)"
            case .pageBottom: return "페이지 하단 (⌘↓)"
            case .brightnessUp: return "밝기 증가"
            case .brightnessDown: return "밝기 감소"
            case .playPause: return "재생/일시정지"
            case .hideApp: return "앱 숨기기 (⌘H)"
            case .forceQuit: return "강제 종료 (⌥⌘Esc)"
            case .terminateApp: return "앱 종료"
            case .sleepDisplay: return "화면 끄기"
            case .kbBrightnessUp: return "키보드 백라이트 증가"
            case .kbBrightnessDown: return "키보드 백라이트 감소"
            case .shortcut: return "Shortcuts 실행"
            case .custom: return "사용자 지정"
            }
        }

        func execute() {
            switch self {
            case .cmdW: postCmdW()
            case .cmdT: postCmdT()
            case .cmdR: postCmdR()
            case .prevTab: postPrevTab()
            case .nextTab: postNextTab()
            case .newWindow: postNewWindow()
            case .minimize: postMinimize()
            case .undo: postUndo()
            case .redo: postRedo()
            case .toggleFullscreen: postToggleFullscreen()
            case .spotlight: postSpotlight()
            case .find: postFind()
            case .back: postBack()
            case .forward: postForward()
            case .addressBar: postAddressBar()
            case .lockScreen: postLockScreen()
            case .copy: postCopy()
            case .paste: postPaste()
            case .cut: postCut()
            case .screenshot: postScreenshot()
            case .selectAll: postSelectAll()
            case .screenCapture: postScreenCapture()
            case .volumeUp: postVolumeUp()
            case .volumeDown: postVolumeDown()
            case .save: postSave()
            case .pageTop: postPageTop()
            case .pageBottom: postPageBottom()
            case .brightnessUp: postBrightnessUp()
            case .brightnessDown: postBrightnessDown()
            case .playPause: postPlayPause()
            case .hideApp: postHideApp()
            case .forceQuit: postForceQuit()
            case .terminateApp: terminateFrontmostApp()
            case .sleepDisplay: postSleepDisplay()
            case .kbBrightnessUp: postKbBrightnessUp()
            case .kbBrightnessDown: postKbBrightnessDown()
            case .shortcut: break // handled separately with shortcut name
            case .custom: break // handled separately with keyCode/flags
            }
        }
    }

    /// Default action mapping for each gesture.
    static let defaultActions: [String: Action] = [
        "ofhLeftTap": .prevTab,
        "ofhRightTap": .nextTab,
        "twhLeftDoubleTap": .cmdR,
        "twhRightDoubleTap": .cmdT,
        "swhLeft": .prevTab,
        "swhRight": .nextTab,
        "swhUp": .newWindow,
        "swhDown": .minimize,
        "threeFingerDoubleTap": .paste,
        "threeFingerClick": .cmdW,
        "threeFingerLongClick": .terminateApp,
        "fourFingerClick": .toggleFullscreen,
        "twoFingerSwipeRight": .back,
        "twoFingerSwipeLeft": .forward,
        "rightSwipeUp": .addressBar,
        "twoFingerDoubleTap": .cut,
        "threeFingerLongPress": .copy,
        "threeFingerTripleTap": .undo,
        "twhLeftLongPress": .save,
        "ofhLeftSwipeUp": .volumeUp,
        "ofhLeftSwipeDown": .volumeDown,
        "ofhRightSwipeUp": .brightnessUp,
        "ofhRightSwipeDown": .brightnessDown,
        "twhRightLongPress": .undo,
        "fourFingerDoubleTap": .screenshot,
        "fourFingerLongPress": .selectAll,
        "fiveFingerTap": .lockScreen,
        "fourFingerLongClick": .hideApp,
        "fiveFingerClick": .forceQuit,
        "threeFingerSwipeRight": .nextTab,
        "threeFingerSwipeLeft": .prevTab,
        "threeFingerSwipeUp": .pageTop,
        "threeFingerSwipeDown": .pageBottom,
        "fiveFingerLongPress": .sleepDisplay,
        "threeFingerSwipeDiagUpRight": .spotlight,
        "threeFingerSwipeDiagUpLeft": .find,
        "threeFingerSwipeDiagDownRight": .pageBottom,
        "threeFingerSwipeDiagDownLeft": .pageTop,
    ]

    /// Execute an Apple Shortcut by name for a gesture.
    static func executeShortcut(gestureId: String) {
        guard let name = GestureConfig.shared.shortcutName(for: gestureId), !name.isEmpty else {
            NSLog("GestureKeys: No shortcut configured for %@", gestureId)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            task.arguments = ["run", name]
            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus != 0 {
                    NSLog("GestureKeys: Shortcut '%@' exited with status %d", name, task.terminationStatus)
                }
            } catch {
                NSLog("GestureKeys: Failed to run shortcut '%@': %@", name, error.localizedDescription)
            }
        }
    }

    /// Execute a custom key combo stored in UserDefaults.
    static func postCustomKey(forGesture gestureId: String) {
        let keyCode = CGKeyCode(UserDefaults.standard.integer(forKey: "customKey.\(gestureId).keyCode"))
        let rawFlags = UserDefaults.standard.integer(forKey: "customKey.\(gestureId).flags")
        // Guard: keyCode=0 with no modifiers means "not configured" (0x00 is 'A' key)
        guard keyCode != 0 || rawFlags != 0 else {
            NSLog("GestureKeys: Custom key not configured for %@", gestureId)
            return
        }
        let flags = CGEventFlags(rawValue: UInt64(rawFlags))
        postKeyCombo(keyCode: keyCode, flags: flags)
    }

    // MARK: - Key Code Display

    /// Shared keyCode → display string mapping (used by KeyCaptureView and CheatSheetView).
    static let keyCodeNames: [UInt16: String] = [
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
        0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q",
        0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1",
        0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
        0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
        0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P", 0x24: "Return",
        0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";", 0x2A: "\\",
        0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M", 0x2F: ".",
        0x30: "Tab", 0x31: "Space", 0x33: "Delete", 0x35: "Esc",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
        0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
        0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
    ]

    /// Returns a display name for a virtual key code.
    static func keyCodeToString(_ keyCode: UInt16) -> String {
        keyCodeNames[keyCode] ?? "Key\(keyCode)"
    }

    // MARK: - Virtual Keycodes

    private static let kVK_ANSI_A: CGKeyCode = 0x00
    private static let kVK_ANSI_W: CGKeyCode = 0x0D
    private static let kVK_ANSI_T: CGKeyCode = 0x11
    private static let kVK_ANSI_R: CGKeyCode = 0x0F
    private static let kVK_ANSI_F: CGKeyCode = 0x03
    private static let kVK_ANSI_N: CGKeyCode = 0x2D
    private static let kVK_ANSI_M: CGKeyCode = 0x2E
    private static let kVK_ANSI_Z: CGKeyCode = 0x06
    private static let kVK_ANSI_Q: CGKeyCode = 0x0C
    private static let kVK_ANSI_L: CGKeyCode = 0x25
    private static let kVK_ANSI_4: CGKeyCode = 0x15
    private static let kVK_ANSI_5: CGKeyCode = 0x17
    private static let kVK_ANSI_X: CGKeyCode = 0x07
    private static let kVK_ANSI_C: CGKeyCode = 0x08
    private static let kVK_ANSI_V: CGKeyCode = 0x09
    private static let kVK_ANSI_LeftBracket: CGKeyCode = 0x21
    private static let kVK_ANSI_RightBracket: CGKeyCode = 0x1E
    private static let kVK_Escape: CGKeyCode = 0x35
    private static let kVK_Space: CGKeyCode = 0x31
    private static let kVK_ANSI_S: CGKeyCode = 0x01
    private static let kVK_UpArrow: CGKeyCode = 0x7E
    private static let kVK_DownArrow: CGKeyCode = 0x7D

    // MARK: - Deferred Execution

    /// Buffer for actions to execute after engineLock release.
    /// Only accessed while engineLock is held — no separate synchronization needed.
    private static var pendingActions: [() -> Void] = []

    /// Appends a deferred action to the pending buffer.
    /// Must be called while engineLock is held.
    static func appendPendingAction(_ action: @escaping () -> Void) {
        pendingActions.append(action)
    }

    /// Atomically takes all pending actions (returns the array and clears the buffer).
    /// Must be called while engineLock is held; execute the returned closures after unlock.
    static func takePendingActions() -> [() -> Void] {
        guard !pendingActions.isEmpty else { return [] }
        var actions: [() -> Void] = []
        swap(&actions, &pendingActions)  // pendingActions keeps existing capacity
        return actions
    }

    // MARK: - Cooldown

    /// Last fire timestamp per gesture ID. Only accessed while engineLock is held.
    private static var lastFireTime: [String: TimeInterval] = [:]

    /// Returns true if the gesture is still in its cooldown period.
    /// Must be called while engineLock is held.
    static func isInCooldown(gestureId: String) -> Bool {
        guard GestureConfig.shared.cooldownEnabled else { return false }
        guard let last = lastFireTime[gestureId] else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        let duration = GestureConfig.shared.cooldownDuration(for: gestureId)
        return (now - last) < duration
    }

    /// Records the fire time for cooldown tracking.
    /// Must be called while engineLock is held.
    static func recordFireTime(gestureId: String) {
        guard GestureConfig.shared.cooldownEnabled else { return }
        lastFireTime[gestureId] = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - Central Dispatch

    /// Central action dispatch — captures config, defers execution to after lock release.
    static func fireAction(gestureId: String) {
        // Monitor mode: record but don't execute
        if GestureEngine.monitorMode {
            GestureMonitor.shared.recordGesture(id: gestureId)
            return
        }

        // Cooldown check (under engineLock)
        if isInCooldown(gestureId: gestureId) { return }
        recordFireTime(gestureId: gestureId)

        // Capture config values while under lock (all in-memory, fast)
        let config = GestureConfig.shared
        let feedback = config.feedbackSnapshot
        let action = config.actionFor(gestureId)
        let gestureInfo = GestureConfig.info(for: gestureId)

        // Defer heavy work (CGEvent posting, HUD, haptic) to after lock release
        pendingActions.append {
            GestureStats.shared.record(gestureId: gestureId)
            if feedback.hudEnabled, let info = gestureInfo {
                GestureHUD.shared.show(name: info.name, action: info.action)
            }
            if feedback.hapticEnabled {
                DispatchQueue.main.async {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            if action == .shortcut {
                executeShortcut(gestureId: gestureId)
            } else if action == .custom {
                postCustomKey(forGesture: gestureId)
            } else {
                action.execute()
            }
        }
    }

    /// Fire action by gesture ID with an explicit action override (for direction-dependent gestures).
    static func fireAction(gestureId: String, action: @escaping () -> Void) {
        if GestureEngine.monitorMode {
            GestureMonitor.shared.recordGesture(id: gestureId)
            return
        }

        // Cooldown check (under engineLock)
        if isInCooldown(gestureId: gestureId) { return }
        recordFireTime(gestureId: gestureId)

        let config = GestureConfig.shared
        let feedback = config.feedbackSnapshot
        let gestureInfo = GestureConfig.info(for: gestureId)

        pendingActions.append {
            GestureStats.shared.record(gestureId: gestureId)
            if feedback.hudEnabled, let info = gestureInfo {
                GestureHUD.shared.show(name: info.name, action: info.action)
            }
            if feedback.hapticEnabled {
                DispatchQueue.main.async {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            action()
        }
    }

    // MARK: - App Actions

    /// Terminates the frontmost application via Apple Events (bypasses Chrome's "Hold ⌘Q" UI).
    static func terminateFrontmostApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            NSLog("GestureKeys: No frontmost application")
            return
        }

        let bundleID = frontApp.bundleIdentifier ?? ""
        if bundleID == "com.apple.finder" || bundleID == "com.gesturekeys.app" {
            NSLog("GestureKeys: Skipping terminate for %@", bundleID)
            return
        }

        NSLog("GestureKeys: Terminating %@", frontApp.localizedName ?? "unknown")
        frontApp.terminate()
    }

    // MARK: - Key Combos (existing)

    static func postCmdW()              { postKeyCombo(keyCode: kVK_ANSI_W, flags: .maskCommand) }
    static func postCmdT()              { postKeyCombo(keyCode: kVK_ANSI_T, flags: .maskCommand) }
    static func postCmdR()              { postKeyCombo(keyCode: kVK_ANSI_R, flags: .maskCommand) }
    static func postPrevTab()           { postKeyCombo(keyCode: kVK_ANSI_LeftBracket, flags: [.maskCommand, .maskShift]) }
    static func postNextTab()           { postKeyCombo(keyCode: kVK_ANSI_RightBracket, flags: [.maskCommand, .maskShift]) }
    static func postNewWindow()         { postKeyCombo(keyCode: kVK_ANSI_N, flags: .maskCommand) }
    static func postMinimize()          { postKeyCombo(keyCode: kVK_ANSI_M, flags: .maskCommand) }
    static func postUndo()              { postKeyCombo(keyCode: kVK_ANSI_Z, flags: .maskCommand) }
    static func postToggleFullscreen()  { postKeyCombo(keyCode: kVK_ANSI_F, flags: [.maskCommand, .maskControl]) }

    // MARK: - Key Combos (new)

    static func postRedo()              { postKeyCombo(keyCode: kVK_ANSI_Z, flags: [.maskCommand, .maskShift]) }
    static func postScreenshot()        { postKeyCombo(keyCode: kVK_ANSI_4, flags: [.maskCommand, .maskShift]) }
    static func postScreenCapture()     { postKeyCombo(keyCode: kVK_ANSI_5, flags: [.maskCommand, .maskShift]) }
    static func postSpotlight()         { postKeyCombo(keyCode: kVK_Space, flags: .maskCommand) }
    static func postBack()              { postKeyCombo(keyCode: kVK_ANSI_LeftBracket, flags: .maskCommand) }
    static func postForward()           { postKeyCombo(keyCode: kVK_ANSI_RightBracket, flags: .maskCommand) }
    static func postAddressBar()        { postKeyCombo(keyCode: kVK_ANSI_L, flags: .maskCommand) }
    static func postFind()              { postKeyCombo(keyCode: kVK_ANSI_F, flags: .maskCommand) }
    static func postLockScreen()        { postKeyCombo(keyCode: kVK_ANSI_Q, flags: [.maskCommand, .maskControl]) }
    static func postForceQuit() {
        // ⌥⌘Esc is handled by WindowServer at a level CGEvent.post can't reach.
        // Use System Events via AppleScript to trigger it reliably.
        lastSynthesisTimestamp = ProcessInfo.processInfo.systemUptime
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", "tell application \"System Events\" to key code 53 using {command down, option down}"]
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                NSLog("GestureKeys: Failed to run force quit: %@", error.localizedDescription)
            }
        }
    }

    static func postSleepDisplay() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            task.arguments = ["displaysleepnow"]
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                NSLog("GestureKeys: Failed to run pmset: %@", error.localizedDescription)
            }
        }
    }

    private static let kVK_ANSI_H: CGKeyCode = 0x04

    static func postHideApp()            { postKeyCombo(keyCode: kVK_ANSI_H, flags: .maskCommand) }
    static func postSave()              { postKeyCombo(keyCode: kVK_ANSI_S, flags: .maskCommand) }
    static func postPageTop()           { postKeyCombo(keyCode: kVK_UpArrow, flags: .maskCommand) }
    static func postPageBottom()        { postKeyCombo(keyCode: kVK_DownArrow, flags: .maskCommand) }

    // MARK: - Clipboard

    static func postSelectAll()          { postKeyCombo(keyCode: kVK_ANSI_A, flags: .maskCommand) }
    static func postCut()               { postKeyCombo(keyCode: kVK_ANSI_X, flags: .maskCommand) }
    static func postCopy()              { postKeyCombo(keyCode: kVK_ANSI_C, flags: .maskCommand) }
    static func postPaste()             { postKeyCombo(keyCode: kVK_ANSI_V, flags: .maskCommand) }

    // MARK: - Media / Volume (system-defined media key events)

    static func postPlayPause()    { postSystemKey(16) }  // NX_KEYTYPE_PLAY
    static func postVolumeUp()     { postSystemKey(0) }   // NX_KEYTYPE_SOUND_UP
    static func postVolumeDown()   { postSystemKey(1) }   // NX_KEYTYPE_SOUND_DOWN
    static func postBrightnessUp()    { postSystemKey(2) }   // NX_KEYTYPE_BRIGHTNESS_UP
    static func postBrightnessDown()  { postSystemKey(3) }   // NX_KEYTYPE_BRIGHTNESS_DOWN
    static func postKbBrightnessUp()  { postSystemKey(21) }  // NX_KEYTYPE_ILLUMINATION_UP
    static func postKbBrightnessDown(){ postSystemKey(22) }  // NX_KEYTYPE_ILLUMINATION_DOWN

    // MARK: - Synthesis Timestamp (for palm rejection)

    /// Lock protecting `lastSynthesisTimestamp` from concurrent read (eventTapCallback)
    /// and write (postKeyCombo/postSystemKey, which run outside engineLock after A1 deferral).
    private static var synthesisLock = os_unfair_lock()
    private static var _lastSynthesisTimestamp: TimeInterval = 0

    /// Timestamp of the last key event we synthesized, so typing suppression
    /// doesn't treat our own output as user typing.
    static var lastSynthesisTimestamp: TimeInterval {
        get {
            os_unfair_lock_lock(&synthesisLock)
            defer { os_unfair_lock_unlock(&synthesisLock) }
            return _lastSynthesisTimestamp
        }
        set {
            os_unfair_lock_lock(&synthesisLock)
            _lastSynthesisTimestamp = newValue
            os_unfair_lock_unlock(&synthesisLock)
        }
    }

    // MARK: - Private

    /// Cached event source (thread-safe; static lazy init uses dispatch_once internally).
    private static let eventSource = CGEventSource(stateID: .hidSystemState)

    private static func postKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let source = eventSource else { return }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }

        keyDown.flags = flags
        keyUp.flags = flags
        lastSynthesisTimestamp = ProcessInfo.processInfo.systemUptime
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func postSystemKey(_ keyType: Int) {
        func post(down: Bool) {
            let flags = down ? 0xa00 : 0xb00
            let data1 = (keyType << 16) | flags
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                timestamp: 0, windowNumber: 0, context: nil,
                subtype: 8, data1: data1, data2: -1
            ) else {
                NSLog("GestureKeys: Failed to create system key event (keyType=%d, down=%@)", keyType, down ? "true" : "false")
                return
            }
            guard let cgEvent = event.cgEvent else {
                NSLog("GestureKeys: System key event has nil cgEvent (keyType=%d)", keyType)
                return
            }
            cgEvent.post(tap: .cghidEventTap)
        }
        lastSynthesisTimestamp = ProcessInfo.processInfo.systemUptime
        post(down: true)
        post(down: false)
    }
}
