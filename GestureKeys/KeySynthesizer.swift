import Foundation
import AppKit
import CoreGraphics
import Carbon

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
        case toggleInputSource = "toggleInputSource"
        case middleClick = "middleClick"
        case snapLeft = "snapLeft"
        case snapRight = "snapRight"
        case snapFill = "snapFill"
        case snapTopLeft = "snapTopLeft"
        case snapTopRight = "snapTopRight"
        case snapBottomLeft = "snapBottomLeft"
        case snapBottomRight = "snapBottomRight"
        case shellCommand = "shellCommand"
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
            case .toggleInputSource: return "한영전환 (⇪)"
            case .middleClick: return "미들클릭"
            case .snapLeft: return "윈도우 왼쪽 절반"
            case .snapRight: return "윈도우 오른쪽 절반"
            case .snapFill: return "윈도우 최대화"
            case .snapTopLeft: return "윈도우 왼쪽 상단"
            case .snapTopRight: return "윈도우 오른쪽 상단"
            case .snapBottomLeft: return "윈도우 왼쪽 하단"
            case .snapBottomRight: return "윈도우 오른쪽 하단"
            case .shellCommand: return "셸 명령 실행"
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
            case .toggleInputSource: postToggleInputSource()
            case .middleClick: postMiddleClick()
            case .snapLeft: postSnapLeft()
            case .snapRight: postSnapRight()
            case .snapFill: postSnapFill()
            case .snapTopLeft: postSnapTopLeft()
            case .snapTopRight: postSnapTopRight()
            case .snapBottomLeft: postSnapBottomLeft()
            case .snapBottomRight: postSnapBottomRight()
            case .shellCommand: break // handled separately with command string
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
        runProcessWithTimeout(
            executable: "/usr/bin/shortcuts",
            arguments: ["run", name],
            timeout: 15.0,
            label: "Shortcut '\(name)'"
        )
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
        0x39: "⇪",
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

        // Macro interception: check if this gesture is part of a macro sequence
        let macroDecision = MacroEngine.shared.interceptGesture(gestureId: gestureId)
        switch macroDecision {
        case .consumed:
            // Gesture consumed by macro — record stats but skip action
            pendingActions.append { GestureStats.shared.record(gestureId: gestureId) }
            return
        case .completed(let macroActions):
            // Macro completed — execute macro actions instead
            pendingActions.append {
                GestureStats.shared.record(gestureId: gestureId)
                MacroEngine.executeMacroActions(macroActions)
            }
            return
        case .passthrough:
            break
        }

        // Standard action dispatch
        fireStandaloneAction(gestureId: gestureId)
    }

    /// Fires a gesture's standalone action (config-aware, with feedback).
    /// Used by normal dispatch and by MacroEngine timeout fallback.
    /// Must be called while engineLock is held.
    static func fireStandaloneAction(gestureId: String) {
        let config = GestureConfig.shared
        let feedback = config.feedbackSnapshot
        let action = config.appAwareActionFor(gestureId)
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
            if action == .shortcut {
                executeShortcut(gestureId: gestureId)
            } else if action == .custom {
                postCustomKey(forGesture: gestureId)
            } else if action == .shellCommand {
                executeShellCommand(gestureId: gestureId)
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
        runProcessWithTimeout(
            executable: "/usr/bin/osascript",
            arguments: ["-e", "tell application \"System Events\" to key code 53 using {command down, option down}"],
            timeout: 10.0,
            label: "Force quit"
        )
    }

    static func postSleepDisplay() {
        runProcessWithTimeout(
            executable: "/usr/bin/pmset",
            arguments: ["displaysleepnow"],
            timeout: 10.0,
            label: "Display sleep"
        )
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

    // MARK: - Middle Click

    static func postMiddleClick() {
        let pos = CGEvent(source: nil)?.location ?? .zero
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown,
                                  mouseCursorPosition: pos, mouseButton: .center),
              let up = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp,
                                mouseCursorPosition: pos, mouseButton: .center) else { return }
        lastSynthesisTimestamp = ProcessInfo.processInfo.systemUptime
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Window Snapping (macOS 15+ native tiling: fn+⌃+Arrow)

    /// Posts fn+Control+Arrow key combo for macOS Sequoia native window tiling.
    private static func postWindowTile(keyCode: CGKeyCode) {
        postKeyCombo(keyCode: keyCode, flags: [.maskControl, .maskSecondaryFn])
    }

    static func postSnapLeft()        { postWindowTile(keyCode: CGKeyCode(kVK_LeftArrow)) }
    static func postSnapRight()       { postWindowTile(keyCode: CGKeyCode(kVK_RightArrow)) }
    static func postSnapFill()        { postWindowTile(keyCode: CGKeyCode(kVK_UpArrow)) }

    /// Quarter tiling: fn+⌃+Arrow → half, then fn+⌃+perpendicular Arrow → quarter.
    /// Posts two sequential tiling commands with a brief delay.
    private static func postWindowQuarter(first: CGKeyCode, second: CGKeyCode) {
        postWindowTile(keyCode: first)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            postWindowTile(keyCode: second)
        }
    }

    static func postSnapTopLeft()     { postWindowQuarter(first: CGKeyCode(kVK_LeftArrow), second: CGKeyCode(kVK_UpArrow)) }
    static func postSnapTopRight()    { postWindowQuarter(first: CGKeyCode(kVK_RightArrow), second: CGKeyCode(kVK_UpArrow)) }
    static func postSnapBottomLeft()  { postWindowQuarter(first: CGKeyCode(kVK_LeftArrow), second: CGKeyCode(kVK_DownArrow)) }
    static func postSnapBottomRight() { postWindowQuarter(first: CGKeyCode(kVK_RightArrow), second: CGKeyCode(kVK_DownArrow)) }

    // MARK: - Shell Command

    static func executeShellCommand(gestureId: String) {
        guard let command = UserDefaults.standard.string(forKey: "shellCommand.\(gestureId)"),
              !command.isEmpty else {
            NSLog("GestureKeys: No shell command configured for %@", gestureId)
            return
        }
        runProcessWithTimeout(
            executable: "/bin/zsh",
            arguments: ["-c", command],
            timeout: 15.0,
            label: "Shell command"
        )
    }

    /// Execute an Apple Shortcut by name (direct, for macro use).
    static func executeShortcut(name: String) {
        runProcessWithTimeout(
            executable: "/usr/bin/shortcuts",
            arguments: ["run", name],
            timeout: 15.0,
            label: "Macro shortcut '\(name)'"
        )
    }

    /// Execute a shell command directly (for macro use).
    static func executeShellCommandDirect(command: String) {
        guard !command.isEmpty else { return }
        runProcessWithTimeout(
            executable: "/bin/zsh",
            arguments: ["-c", command],
            timeout: 15.0,
            label: "Macro shell command"
        )
    }

    // MARK: - Process Execution with Timeout

    /// Runs an external process on a background thread with a timeout.
    /// If the process doesn't exit within `timeout` seconds, it is terminated
    /// to prevent indefinite GCD thread pool exhaustion from hanging commands.
    private static func runProcessWithTimeout(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        label: String
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: executable)
            task.arguments = arguments
            do {
                try task.run()
            } catch {
                NSLog("GestureKeys: Failed to run %@: %@", label, error.localizedDescription)
                return
            }

            // Wait with timeout — kill the process if it hangs
            let deadline = DispatchTime.now() + timeout
            let semaphore = DispatchSemaphore(value: 0)
            task.terminationHandler = { _ in semaphore.signal() }

            if semaphore.wait(timeout: deadline) == .timedOut {
                if task.isRunning {
                    NSLog("GestureKeys: %@ timed out after %.0fs — terminating", label, timeout)
                    task.terminate()
                }
            } else if task.terminationStatus != 0 {
                NSLog("GestureKeys: %@ exited with status %d", label, task.terminationStatus)
            }
        }
    }

    // MARK: - Media / Volume (system-defined media key events)

    static func postPlayPause()    { postSystemKey(16) }  // NX_KEYTYPE_PLAY
    static func postVolumeUp()     { postSystemKey(0) }   // NX_KEYTYPE_SOUND_UP
    static func postVolumeDown()   { postSystemKey(1) }   // NX_KEYTYPE_SOUND_DOWN
    static func postBrightnessUp()    { postSystemKey(2) }   // NX_KEYTYPE_BRIGHTNESS_UP
    static func postBrightnessDown()  { postSystemKey(3) }   // NX_KEYTYPE_BRIGHTNESS_DOWN
    static func postKbBrightnessUp()  { postSystemKey(21) }  // NX_KEYTYPE_ILLUMINATION_UP
    static func postKbBrightnessDown(){ postSystemKey(22) }  // NX_KEYTYPE_ILLUMINATION_DOWN

    // MARK: - Input Source Toggle

    /// Cached selectable keyboard input sources. Built once, invalidated on system notification.
    private static var cachedSources: [TISInputSource]?
    /// Maps input source ID → index in `cachedSources` for O(1) lookup.
    private static var sourceIdToIndex: [String: Int] = [:]
    /// Lock protecting cached input source data.
    private static var inputSourceLock = os_unfair_lock()
    /// Whether we registered for the input source change notification.
    private static var observingInputSourceChanges = false
    /// Observer token for input source change notification (for explicit removal).
    private static var inputSourceObserver: NSObjectProtocol?

    /// Registers for system input source change notifications to invalidate cache.
    static func startObservingInputSourceChanges() {
        os_unfair_lock_lock(&inputSourceLock)
        guard !observingInputSourceChanges else {
            os_unfair_lock_unlock(&inputSourceLock)
            return
        }
        observingInputSourceChanges = true
        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: .init(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: nil
        ) { _ in
            os_unfair_lock_lock(&inputSourceLock)
            cachedSources = nil
            sourceIdToIndex = [:]
            os_unfair_lock_unlock(&inputSourceLock)
        }
        os_unfair_lock_unlock(&inputSourceLock)
    }

    /// Rebuilds the cached input source list.
    private static func rebuildSourceCache() -> [TISInputSource]? {
        guard let category = kTISCategoryKeyboardInputSource else { return nil }
        let conditions = [
            kTISPropertyInputSourceCategory: category,
            kTISPropertyInputSourceIsSelectCapable: kCFBooleanTrue!
        ] as CFDictionary
        guard let sourcesCF = TISCreateInputSourceList(conditions, false)?
                .takeRetainedValue() as? [TISInputSource],
              sourcesCF.count >= 2
        else { return nil }

        var idMap: [String: Int] = [:]
        for (i, src) in sourcesCF.enumerated() {
            if let srcId = inputSourceID(src) {
                idMap[srcId] = i
            }
        }

        os_unfair_lock_lock(&inputSourceLock)
        cachedSources = sourcesCF
        sourceIdToIndex = idMap
        os_unfair_lock_unlock(&inputSourceLock)
        return sourcesCF
    }

    /// Pre-builds the input source cache so the first Caps Lock toggle
    /// doesn't incur a TISCreateInputSourceList() delay (~2-5ms).
    static func prewarmInputSourceCache() {
        os_unfair_lock_lock(&inputSourceLock)
        let needsBuild = cachedSources == nil
        os_unfair_lock_unlock(&inputSourceLock)
        if needsBuild {
            _ = rebuildSourceCache()
        }
    }

    /// Invalidates the cached input source list so it is rebuilt on next toggle.
    /// Also removes the DistributedNotificationCenter observer to prevent
    /// unnecessary cache updates while the engine is stopped.
    static func invalidateInputSourceCache() {
        let observer: NSObjectProtocol?
        os_unfair_lock_lock(&inputSourceLock)
        cachedSources = nil
        sourceIdToIndex = [:]
        observer = inputSourceObserver
        inputSourceObserver = nil
        observingInputSourceChanges = false
        os_unfair_lock_unlock(&inputSourceLock)

        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private static func inputSourceID(_ source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private static func inputSourceName(_ source: TISInputSource) -> String {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return "" }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private static func inputSourceBool(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
    }

    private static func isKoreanInputSource(_ source: TISInputSource) -> Bool {
        let sourceText = "\(inputSourceID(source) ?? "") \(inputSourceName(source))"
        return sourceText.localizedCaseInsensitiveContains("korean")
            || sourceText.localizedCaseInsensitiveContains("hangul")
    }

    private static func isLatinInputSource(_ source: TISInputSource) -> Bool {
        inputSourceBool(source, kTISPropertyInputSourceIsASCIICapable)
            && !isKoreanInputSource(source)
    }

    private static func selectedSourceIndex(in sources: [TISInputSource]) -> Int? {
        sources.firstIndex { inputSourceBool($0, kTISPropertyInputSourceIsSelected) }
    }

    private static func preferredInputSourceTargetIndex(
        current: TISInputSource,
        currentIdx: Int?,
        sources: [TISInputSource]
    ) -> Int? {
        let koreanIndices = sources.indices.filter { isKoreanInputSource(sources[$0]) }
        let latinIndices = sources.indices.filter { isLatinInputSource(sources[$0]) }
        guard !koreanIndices.isEmpty, !latinIndices.isEmpty else { return nil }

        let currentIsKorean = currentIdx.map { isKoreanInputSource(sources[$0]) } ?? isKoreanInputSource(current)
        return currentIsKorean ? latinIndices.first : koreanIndices.first
    }

    /// Core toggle logic. Returns true if the switch succeeded.
    private static func performToggle(sources: [TISInputSource], idMap: [String: Int]) -> Bool {
        guard !sources.isEmpty else { return false }
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let currentIdx = inputSourceID(current).flatMap { idMap[$0] } ?? selectedSourceIndex(in: sources)
        let fallbackIdx = currentIdx ?? 0
        let targetIdx = preferredInputSourceTargetIndex(
            current: current,
            currentIdx: currentIdx,
            sources: sources
        ) ?? ((fallbackIdx + 1) % sources.count)

        let status = TISSelectInputSource(sources[targetIdx])
        if status != noErr {
            NSLog("GestureKeys: Input source select failed with status %d", status)
            return false
        }
        return true
    }

    /// Toggles the keyboard input source (e.g. Korean ↔ English).
    /// Uses Carbon TIS API with cached source list for minimal latency.
    /// Runs synchronously so the switch completes before the next key event
    /// reaches the EventTap — prevents first-keystroke-in-wrong-source race.
    /// With caching, total block time is ~6-25ms (safe for EventTap).
    /// On failure (stale cache), invalidates and retries once.
    @discardableResult
    static func postToggleInputSource() -> Bool {
        // Read cached sources
        os_unfair_lock_lock(&inputSourceLock)
        var sources = cachedSources
        var idMap = sourceIdToIndex
        os_unfair_lock_unlock(&inputSourceLock)

        // Rebuild cache if needed (first call or after invalidation)
        if sources == nil {
            sources = rebuildSourceCache()
            os_unfair_lock_lock(&inputSourceLock)
            idMap = sourceIdToIndex
            os_unfair_lock_unlock(&inputSourceLock)
        }

        guard let sources, sources.count >= 2 else {
            NSLog("GestureKeys: Input source toggle skipped — fewer than 2 sources available")
            return false
        }

        if performToggle(sources: sources, idMap: idMap) { return true }

        // Toggle failed — cached sources likely stale. Invalidate and retry once.
        guard let freshSources = rebuildSourceCache(), freshSources.count >= 2 else {
            NSLog("GestureKeys: Input source toggle failed — cache rebuild returned no sources")
            return false
        }
        os_unfair_lock_lock(&inputSourceLock)
        let freshMap = sourceIdToIndex
        os_unfair_lock_unlock(&inputSourceLock)
        if !performToggle(sources: freshSources, idMap: freshMap) {
            NSLog("GestureKeys: Input source toggle failed after retry")
            return false
        }
        return true
    }

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
