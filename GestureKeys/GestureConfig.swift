import Foundation
import Combine
import AppKit

/// Stores per-gesture enable/disable settings, persisted in UserDefaults.
///
/// - `isEnabled(_:)` reads from UserDefaults (thread-safe for recognizer callbacks).
/// - `setEnabled(_:_:)` writes to UserDefaults and updates @Published state for SwiftUI.
final class GestureConfig: ObservableObject {

    static let shared = GestureConfig()

    // MARK: - Gesture Definitions

    struct Info: Identifiable {
        let id: String
        let name: String
        let action: String
        let defaultEnabled: Bool
        let howTo: String
    }

    struct Category: Identifiable {
        let id: String
        let title: String
        let icon: String
        let gestures: [Info]
    }

    static let categories: [Category] = [
        Category(id: "tabs", title: "탭 관리", icon: "rectangle.stack", gestures: [
            Info(id: "ofhLeftTap",            name: "한 손가락 홀드 + 왼쪽 탭",    action: "이전 탭 (⇧⌘[)",             defaultEnabled: true,
                 howTo: "한 손가락을 트랙패드에 올려 0.2초 유지한 뒤, 그 왼쪽을 다른 손가락으로 빠르게 탭하세요."),
            Info(id: "ofhRightTap",           name: "한 손가락 홀드 + 오른쪽 탭",  action: "다음 탭 (⇧⌘])",             defaultEnabled: true,
                 howTo: "한 손가락을 트랙패드에 올려 0.2초 유지한 뒤, 그 오른쪽을 다른 손가락으로 빠르게 탭하세요."),
            Info(id: "twhLeftDoubleTap",      name: "홀드 + 왼쪽 더블탭",         action: "새로고침 (⌘R)",              defaultEnabled: true,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 왼쪽에서 세 번째 손가락으로 빠르게 두 번 탭하세요."),
            Info(id: "twhRightDoubleTap",     name: "홀드 + 오른쪽 더블탭",       action: "새 탭 (⌘T)",                defaultEnabled: true,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 오른쪽에서 세 번째 손가락으로 빠르게 두 번 탭하세요."),
            Info(id: "swhLeft",              name: "홀드 + 스와이프 ←",          action: "이전 탭 (⇧⌘[)",             defaultEnabled: true,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 세 번째 손가락으로 왼쪽으로 밀어주세요."),
            Info(id: "swhRight",             name: "홀드 + 스와이프 →",          action: "다음 탭 (⇧⌘])",             defaultEnabled: true,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 세 번째 손가락으로 오른쪽으로 밀어주세요."),
            Info(id: "threeFingerSwipeRight", name: "세 손가락 스와이프 →",        action: "다음 탭 (⇧⌘])",             defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 오른쪽으로 밀어주세요. 수평 방향이 수직보다 2.5배 이상 커야 합니다."),
            Info(id: "threeFingerSwipeLeft",  name: "세 손가락 스와이프 ←",        action: "이전 탭 (⇧⌘[)",             defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 왼쪽으로 밀어주세요. 수평 방향이 수직보다 2.5배 이상 커야 합니다."),
        ]),
        Category(id: "windows", title: "창 관리", icon: "macwindow", gestures: [
            Info(id: "threeFingerClick",      name: "세 손가락 클릭",             action: "탭 닫기 (⌘W)",               defaultEnabled: true,
                 howTo: "세 손가락을 트랙패드에 올린 뒤, 물리적으로 트랙패드를 꾹 눌러 클릭하세요."),
            Info(id: "threeFingerLongClick",  name: "세 손가락 세게 클릭",         action: "앱 종료 (⌘Q)",               defaultEnabled: false,
                 howTo: "세 손가락을 트랙패드에 올린 뒤 세게 눌러 클릭하세요 (Force Touch). Force Touch 미지원 시 0.5초 유지로 동작합니다."),
            Info(id: "fourFingerClick",       name: "네 손가락 클릭",             action: "전체화면 토글 (⌃⌘F)",        defaultEnabled: true,
                 howTo: "네 손가락을 트랙패드에 올린 뒤, 물리적으로 트랙패드를 꾹 눌러 클릭하세요."),
            Info(id: "fourFingerLongClick",  name: "네 손가락 세게 클릭",         action: "앱 숨기기 (⌘H)",            defaultEnabled: false,
                 howTo: "네 손가락을 트랙패드에 올린 뒤 세게 눌러 클릭하세요 (Force Touch). 바로 떼면 전체화면 토글입니다."),
            Info(id: "swhUp",               name: "홀드 + 스와이프 ↑",          action: "새 창 (⌘N)",                defaultEnabled: true,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 왼쪽의 세 번째 손가락으로 위로 밀어주세요."),
            Info(id: "swhDown",             name: "홀드 + 스와이프 ↓",          action: "최소화 (⌘M)",               defaultEnabled: true,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 왼쪽의 세 번째 손가락으로 아래로 밀어주세요."),
        ]),
        Category(id: "navigation", title: "탐색", icon: "safari", gestures: [
            Info(id: "twoFingerSwipeRight",  name: "두 손가락 스와이프 →",         action: "뒤로가기 (⌘[)",              defaultEnabled: true,
                 howTo: "두 손가락을 동시에 빠르게 오른쪽으로 밀어주세요. 수평 방향이 수직보다 2.5배 이상 커야 합니다."),
            Info(id: "twoFingerSwipeLeft",   name: "두 손가락 스와이프 ←",         action: "앞으로가기 (⌘])",            defaultEnabled: true,
                 howTo: "두 손가락을 동시에 빠르게 왼쪽으로 밀어주세요. 수평 방향이 수직보다 2.5배 이상 커야 합니다."),
            Info(id: "rightSwipeUp",         name: "홀드 + 오른쪽 스와이프 ↑",    action: "주소창 (⌘L)",               defaultEnabled: false,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 오른쪽의 세 번째 손가락으로 위로 밀어주세요."),
            Info(id: "threeFingerSwipeUp",   name: "세 손가락 스와이프 ↑",        action: "페이지 상단 (⌘↑)",          defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 위로 밀어주세요. 수직 방향이 수평보다 2.5배 이상 커야 합니다."),
            Info(id: "threeFingerSwipeDown", name: "세 손가락 스와이프 ↓",        action: "페이지 하단 (⌘↓)",          defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 아래로 밀어주세요. 수직 방향이 수평보다 2.5배 이상 커야 합니다."),
            Info(id: "threeFingerSwipeDiagUpRight", name: "세 손가락 대각선 ↗",   action: "Spotlight (⌘Space)",        defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 오른쪽 위 대각선으로 밀어주세요."),
            Info(id: "threeFingerSwipeDiagUpLeft",  name: "세 손가락 대각선 ↖",   action: "검색 (⌘F)",                defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 왼쪽 위 대각선으로 밀어주세요."),
            Info(id: "threeFingerSwipeDiagDownRight", name: "세 손가락 대각선 ↘", action: "페이지 하단 (⌘↓)",         defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 오른쪽 아래 대각선으로 밀어주세요."),
            Info(id: "threeFingerSwipeDiagDownLeft",  name: "세 손가락 대각선 ↙", action: "페이지 상단 (⌘↑)",         defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 왼쪽 아래 대각선으로 밀어주세요."),
        ]),
        Category(id: "editing", title: "편집", icon: "pencil", gestures: [
            Info(id: "twoFingerDoubleTap",   name: "두 손가락 더블탭",            action: "잘라내기 (⌘X)",              defaultEnabled: true,
                 howTo: "두 손가락을 동시에 빠르게 두 번 탭하세요."),
            Info(id: "threeFingerDoubleTap", name: "세 손가락 더블탭",            action: "붙여넣기 (⌘V)",              defaultEnabled: true,
                 howTo: "세 손가락을 동시에 빠르게 두 번 탭하세요."),
            Info(id: "threeFingerLongPress", name: "세 손가락 길게 누르기",        action: "복사 (⌘C)",                  defaultEnabled: true,
                 howTo: "세 손가락을 트랙패드에 올리고 0.5초 이상 움직이지 않고 유지하세요."),
            Info(id: "threeFingerTripleTap", name: "세 손가락 트리플탭",         action: "실행 취소 (⌘Z)",             defaultEnabled: false,
                 howTo: "세 손가락을 동시에 빠르게 세 번 탭하세요."),
            Info(id: "twhLeftLongPress",     name: "홀드 + 왼쪽 길게",            action: "저장 (⌘S)",                  defaultEnabled: false,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 왼쪽에서 세 번째 손가락을 0.4초 이상 유지하세요."),
            Info(id: "twhRightLongPress",    name: "홀드 + 오른쪽 길게",          action: "실행취소 (⌘Z)",              defaultEnabled: false,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 오른쪽에서 세 번째 손가락을 0.4초 이상 유지하세요."),
        ]),
        Category(id: "system", title: "시스템", icon: "gearshape", gestures: [
            Info(id: "ofhLeftSwipeUp",       name: "한 손가락 홀드 + 왼쪽 ↑",     action: "볼륨 증가",                  defaultEnabled: false,
                 howTo: "한 손가락을 트랙패드에 올려 0.2초 유지한 뒤, 그 왼쪽에서 다른 손가락으로 위로 밀어주세요."),
            Info(id: "ofhLeftSwipeDown",     name: "한 손가락 홀드 + 왼쪽 ↓",     action: "볼륨 감소",                  defaultEnabled: false,
                 howTo: "한 손가락을 트랙패드에 올려 0.2초 유지한 뒤, 그 왼쪽에서 다른 손가락으로 아래로 밀어주세요."),
            Info(id: "ofhRightSwipeUp",     name: "한 손가락 홀드 + 오른쪽 ↑",   action: "밝기 증가",                  defaultEnabled: false,
                 howTo: "한 손가락을 트랙패드에 올려 0.2초 유지한 뒤, 그 오른쪽에서 다른 손가락으로 위로 밀어주세요."),
            Info(id: "ofhRightSwipeDown",   name: "한 손가락 홀드 + 오른쪽 ↓",   action: "밝기 감소",                  defaultEnabled: false,
                 howTo: "한 손가락을 트랙패드에 올려 0.2초 유지한 뒤, 그 오른쪽에서 다른 손가락으로 아래로 밀어주세요."),
            Info(id: "rightSwipeUpDown",     name: "홀드 + 오른쪽 스와이프 ↑↓",   action: "볼륨 조절",                  defaultEnabled: false,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 오른쪽의 세 번째 손가락으로 위/아래로 밀어 볼륨을 조절하세요."),
            Info(id: "fourFingerDoubleTap",  name: "네 손가락 더블탭",            action: "스크린샷 (⇧⌘4)",             defaultEnabled: false,
                 howTo: "네 손가락을 동시에 빠르게 두 번 탭하세요. 손가락을 움직이지 않도록 주의하세요."),
            Info(id: "fourFingerLongPress",  name: "네 손가락 길게 누르기",       action: "전체 선택 (⌘A)",             defaultEnabled: false,
                 howTo: "네 손가락을 트랙패드에 올리고 0.5초 이상 움직이지 않고 유지하세요."),
            Info(id: "fiveFingerTap",        name: "다섯 손가락 탭",             action: "잠금화면 (⌃⌘Q)",             defaultEnabled: false,
                 howTo: "다섯 손가락을 동시에 트랙패드에 올렸다가 빠르게 떼세요. 0.4초 이내에 완료해야 합니다."),
            Info(id: "fiveFingerClick",      name: "다섯 손가락 세게 클릭",       action: "강제 종료 (⌥⌘Esc)",          defaultEnabled: false,
                 howTo: "다섯 손가락을 트랙패드에 올린 뒤 세게 눌러 클릭하세요 (Force Touch 필수). 일반 클릭으로는 발동되지 않습니다."),
            Info(id: "fiveFingerLongPress", name: "다섯 손가락 길게 누르기",     action: "화면 끄기",                   defaultEnabled: false,
                 howTo: "다섯 손가락을 트랙패드에 올리고 0.5초 이상 움직이지 않고 유지하세요."),
        ]),
    ]

    static var all: [Info] { categories.flatMap { $0.gestures } }

    /// O(1) lookup for gesture info by ID (built once at init).
    private static let infoMap: [String: Info] = {
        var map: [String: Info] = [:]
        for info in all { map[info.id] = info }
        return map
    }()

    /// O(1) lookup for default enabled state by gesture ID.
    private static let defaultEnabledMap: [String: Bool] = {
        var map: [String: Bool] = [:]
        for info in all { map[info.id] = info.defaultEnabled }
        return map
    }()

    /// Look up gesture info by ID. O(1).
    static func info(for id: String) -> Info? {
        infoMap[id]
    }

    // MARK: - State

    /// Published cache for SwiftUI observation (main thread only).
    @Published private var states: [String: Bool] = [:]

    /// Thread-safe enabled state cache for hot-path reads from touch callback thread.
    /// Protected by its own lock to avoid UserDefaults I/O in the touch processing loop.
    private var enabledLock = os_unfair_lock()
    private var enabledCache: [String: Bool] = [:]

    /// Cached action mappings — avoids UserDefaults reads and string interpolation under engine lock.
    private var actionCache: [String: KeySynthesizer.Action] = [:]

    /// Cached frontmost app bundle ID (updated by GestureEngine under engineLock).
    /// Protected by enabledLock for consistent reads from isEnabled().
    var cachedFrontmostBundleId: String? {
        get {
            os_unfair_lock_lock(&enabledLock)
            defer { os_unfair_lock_unlock(&enabledLock) }
            return _cachedFrontmostBundleId
        }
        set {
            os_unfair_lock_lock(&enabledLock)
            _cachedFrontmostBundleId = newValue
            os_unfair_lock_unlock(&enabledLock)
        }
    }
    private var _cachedFrontmostBundleId: String?

    /// Last frontmost bundle ID that wasn't GestureKeys itself.
    /// Used by AppOverrideView "현재 앱" button to avoid capturing our own app.
    var lastExternalBundleId: String?

    /// Cached multiplier values for hot-path reads (updated on settings change).
    /// Protected by enabledLock — write via refreshCache(), read via effective* accessors.
    private var cachedTapSpeed: Double = 1.0
    private var cachedSwipeMultiplier: Double = 1.0
    private var cachedMoveMultiplier: Double = 1.0
    private var cachedTypingSupprEnabled: Bool = true
    private var cachedTypingSupprWindow: Double = 0.3

    /// Thread-safe snapshot of typing suppression settings (single lock acquisition).
    var typingSuppressionSnapshot: (enabled: Bool, window: Double) {
        os_unfair_lock_lock(&enabledLock)
        let e = cachedTypingSupprEnabled
        let w = cachedTypingSupprWindow
        os_unfair_lock_unlock(&enabledLock)
        return (e, w)
    }

    /// Per-frame snapshot of all sensitivity multipliers (single lock acquisition).
    /// Call once per touch frame, then pass to recognizers to avoid ~50 individual lock/unlock cycles.
    struct SensitivitySnapshot {
        let tapSpeed: Double
        let swipeMultiplier: Double
        let moveMultiplier: Double

        func maxTapDuration() -> TimeInterval { 0.250 * tapSpeed }
        func doubleTapWindow() -> TimeInterval { 0.400 * tapSpeed }
        func multiTapWindow() -> TimeInterval { 0.350 * tapSpeed }
        func holdStability() -> TimeInterval { 0.100 * tapSpeed }
        func longPressDuration(base: Double) -> TimeInterval { base * tapSpeed }
        func swipeThreshold(base: Float) -> Float { base * Float(swipeMultiplier) }
        func moveThreshold(base: Float) -> Float { base * Float(moveMultiplier) }
    }

    /// Thread-safe snapshot of all cached multipliers (single lock acquisition per frame).
    var sensitivitySnapshot: SensitivitySnapshot {
        os_unfair_lock_lock(&enabledLock)
        let snap = SensitivitySnapshot(
            tapSpeed: cachedTapSpeed,
            swipeMultiplier: cachedSwipeMultiplier,
            moveMultiplier: cachedMoveMultiplier
        )
        os_unfair_lock_unlock(&enabledLock)
        return snap
    }

    private init() {
        for info in Self.all {
            let key = "gesture.\(info.id)"
            let value: Bool
            if let stored = UserDefaults.standard.object(forKey: key) as? Bool {
                value = stored
            } else {
                value = info.defaultEnabled
            }
            states[info.id] = value
            enabledCache[info.id] = value

            // Pre-cache action mappings
            if let raw = UserDefaults.standard.string(forKey: "action.\(info.id)"),
               let action = KeySynthesizer.Action(rawValue: raw) {
                actionCache[info.id] = action
            } else {
                actionCache[info.id] = KeySynthesizer.defaultActions[info.id]
            }
        }
        refreshCache()
        cachedHudEnabled = UserDefaults.standard.object(forKey: "hudEnabled") as? Bool ?? false
        cachedHapticEnabled = UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true
        cachedCooldownEnabled = UserDefaults.standard.object(forKey: "cooldownEnabled") as? Bool ?? false
        loadCooldownOverrides()

        // Pre-populate app overrides cache to avoid first-access allocation under lock
        if let dict = UserDefaults.standard.dictionary(forKey: "appOverrides") as? [String: [String]] {
            cachedAppOverrides = dict.mapValues { Set($0) }
        } else {
            cachedAppOverrides = [:]
        }
    }

    /// Clamps a value to a valid range.
    private static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, value))
    }

    /// Refreshes cached values from UserDefaults (with bounds validation).
    /// Thread-safe: writes under enabledLock to synchronize with touch callback reads.
    func refreshCache() {
        let tapSpeed = Self.clamp(UserDefaults.standard.object(forKey: "tapSpeedMultiplier") as? Double ?? 1.0, 0.5, 2.0)
        let swipeMult = Self.clamp(UserDefaults.standard.object(forKey: "swipeThresholdMultiplier") as? Double ?? 1.0, 0.5, 2.0)
        let moveMult = Self.clamp(UserDefaults.standard.object(forKey: "moveThresholdMultiplier") as? Double ?? 1.0, 0.5, 2.0)
        let typingEnabled = UserDefaults.standard.object(forKey: "typingSuppressionEnabled") as? Bool ?? true
        let typingWindow = Self.clamp(UserDefaults.standard.object(forKey: "typingSuppressionWindow") as? Double ?? 0.3, 0.1, 1.0)

        os_unfair_lock_lock(&enabledLock)
        cachedTapSpeed = tapSpeed
        cachedSwipeMultiplier = swipeMult
        cachedMoveMultiplier = moveMult
        cachedTypingSupprEnabled = typingEnabled
        cachedTypingSupprWindow = typingWindow
        os_unfair_lock_unlock(&enabledLock)
    }

    // MARK: - API

    /// Thread-safe read from in-memory cache (no UserDefaults I/O).
    /// Also checks per-app overrides via frameAppOverrides (snapshotted per frame).
    func isEnabled(_ id: String) -> Bool {
        os_unfair_lock_lock(&enabledLock)
        let globalEnabled = enabledCache[id] ?? (Self.defaultEnabledMap[id] ?? false)
        os_unfair_lock_unlock(&enabledLock)
        guard globalEnabled else { return false }

        // Check per-app override from frame snapshot (no extra lock acquisition)
        if let overrides = frameAppOverrides, overrides.contains(id) {
            return false
        }
        return true
    }

    /// Main thread write (called from UI).
    func setEnabled(_ id: String, _ enabled: Bool) {
        states[id] = enabled
        os_unfair_lock_lock(&enabledLock)
        enabledCache[id] = enabled
        os_unfair_lock_unlock(&enabledLock)
        UserDefaults.standard.set(enabled, forKey: "gesture.\(id)")
    }

    /// For SwiftUI binding reads.
    func uiIsEnabled(_ id: String) -> Bool {
        states[id] ?? false
    }

    /// Reloads all settings from UserDefaults (e.g. after settings import).
    /// Must be called on the main thread.
    func reloadFromDefaults() {
        let defaults = UserDefaults.standard
        os_unfair_lock_lock(&enabledLock)
        for info in Self.all {
            let key = "gesture.\(info.id)"
            let value: Bool
            if let stored = defaults.object(forKey: key) as? Bool {
                value = stored
            } else {
                value = info.defaultEnabled
            }
            states[info.id] = value
            enabledCache[info.id] = value

            if let raw = defaults.string(forKey: "action.\(info.id)"),
               let action = KeySynthesizer.Action(rawValue: raw) {
                actionCache[info.id] = action
            } else {
                actionCache[info.id] = KeySynthesizer.defaultActions[info.id]
            }
        }
        os_unfair_lock_unlock(&enabledLock)

        cachedHudEnabled = defaults.object(forKey: "hudEnabled") as? Bool ?? false
        cachedHapticEnabled = defaults.object(forKey: "hapticEnabled") as? Bool ?? true
        cachedCooldownEnabled = defaults.object(forKey: "cooldownEnabled") as? Bool ?? false
        loadCooldownOverrides()
        refreshCache()

        // Reload app overrides
        os_unfair_lock_lock(&appOverridesLock)
        if let dict = defaults.dictionary(forKey: "appOverrides") as? [String: [String]] {
            cachedAppOverrides = dict.mapValues { Set($0) }
        } else {
            cachedAppOverrides = [:]
        }
        os_unfair_lock_unlock(&appOverridesLock)

        objectWillChange.send()
    }

    // MARK: - Action Remapping

    /// Returns the action assigned to a gesture (default or remapped).
    /// Thread-safe: reads from in-memory cache under enabledLock.
    func actionFor(_ gestureId: String) -> KeySynthesizer.Action {
        os_unfair_lock_lock(&enabledLock)
        let action = actionCache[gestureId]
        os_unfair_lock_unlock(&enabledLock)
        return action ?? KeySynthesizer.defaultActions[gestureId] ?? .cmdW
    }

    /// Sets a remapped action for a gesture.
    /// Thread-safe: writes to actionCache under enabledLock.
    func setAction(_ gestureId: String, _ action: KeySynthesizer.Action) {
        os_unfair_lock_lock(&enabledLock)
        actionCache[gestureId] = action
        os_unfair_lock_unlock(&enabledLock)
        UserDefaults.standard.set(action.rawValue, forKey: "action.\(gestureId)")
        objectWillChange.send()
    }

    /// Returns the display name of the current action for a gesture.
    func actionDisplayName(_ gestureId: String) -> String {
        actionFor(gestureId).displayName
    }

    // MARK: - Per-App Overrides

    /// Lock protecting cachedAppOverrides from concurrent read (touch thread) / write (main thread).
    private var appOverridesLock = os_unfair_lock()

    /// Cached app overrides to avoid reconstructing from UserDefaults on every isEnabled() call.
    private var cachedAppOverrides: [String: Set<String>]?

    /// bundleId → set of disabled gesture IDs for that app.
    /// Stored as `[String: [String]]` in UserDefaults.
    /// Thread-safe: protected by appOverridesLock.
    var appOverrides: [String: Set<String>] {
        get {
            os_unfair_lock_lock(&appOverridesLock)
            defer { os_unfair_lock_unlock(&appOverridesLock) }
            if let cached = cachedAppOverrides { return cached }
            guard let dict = UserDefaults.standard.dictionary(forKey: "appOverrides") as? [String: [String]] else {
                cachedAppOverrides = [:]
                return [:]
            }
            let result = dict.mapValues { Set($0) }
            cachedAppOverrides = result
            return result
        }
        set {
            os_unfair_lock_lock(&appOverridesLock)
            let dict = newValue.mapValues { Array($0) }
            UserDefaults.standard.set(dict, forKey: "appOverrides")
            cachedAppOverrides = newValue
            os_unfair_lock_unlock(&appOverridesLock)
            objectWillChange.send()
        }
    }

    /// Returns the list of bundle IDs that have overrides.
    var overriddenBundleIds: [String] {
        Array(appOverrides.keys).sorted()
    }

    func isGestureDisabledForApp(_ gestureId: String, bundleId: String) -> Bool {
        appOverrides[bundleId]?.contains(gestureId) ?? false
    }

    func setGestureDisabledForApp(_ gestureId: String, bundleId: String, disabled: Bool) {
        var overrides = appOverrides
        var set = overrides[bundleId] ?? []
        if disabled {
            set.insert(gestureId)
        } else {
            set.remove(gestureId)
        }
        if set.isEmpty {
            overrides.removeValue(forKey: bundleId)
        } else {
            overrides[bundleId] = set
        }
        appOverrides = overrides
    }

    func removeAppOverride(bundleId: String) {
        var overrides = appOverrides
        overrides.removeValue(forKey: bundleId)
        appOverrides = overrides
    }

    // MARK: - HUD & Haptic

    /// Cached values for hot-path reads (avoids UserDefaults I/O under engine lock).
    /// Protected by enabledLock for thread-safe read from touch callback / write from main thread.
    private var cachedHudEnabled: Bool = false
    private var cachedHapticEnabled: Bool = true

    /// Thread-safe snapshot of HUD/haptic settings (single lock acquisition).
    var feedbackSnapshot: (hudEnabled: Bool, hapticEnabled: Bool) {
        os_unfair_lock_lock(&enabledLock)
        let h = cachedHudEnabled
        let p = cachedHapticEnabled
        os_unfair_lock_unlock(&enabledLock)
        return (h, p)
    }

    var hudEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "hudEnabled") as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: "hudEnabled")
            os_unfair_lock_lock(&enabledLock)
            cachedHudEnabled = newValue
            os_unfair_lock_unlock(&enabledLock)
            objectWillChange.send()
        }
    }

    var hapticEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "hapticEnabled")
            os_unfair_lock_lock(&enabledLock)
            cachedHapticEnabled = newValue
            os_unfair_lock_unlock(&enabledLock)
            objectWillChange.send()
        }
    }

    // MARK: - Zone-Based Actions

    /// Gestures that support left/right zone-based action mapping.
    static let zoneCapableGestures: Set<String> = [
        "twoFingerDoubleTap", "threeFingerDoubleTap", "threeFingerClick", "fiveFingerTap"
    ]

    /// Whether zone-based actions are enabled for a gesture.
    func zonesEnabled(for gestureId: String) -> Bool {
        UserDefaults.standard.object(forKey: "zones.enabled.\(gestureId)") as? Bool ?? false
    }

    /// Sets whether zone-based actions are enabled for a gesture.
    func setZonesEnabled(for gestureId: String, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "zones.enabled.\(gestureId)")
        objectWillChange.send()
    }

    /// Returns the action for a gesture in a specific zone (or nil if not configured).
    func zoneAction(for gestureId: String, zone: TrackpadZone) -> KeySynthesizer.Action? {
        guard let raw = UserDefaults.standard.string(forKey: "zones.\(gestureId).\(zone.rawValue)"),
              let action = KeySynthesizer.Action(rawValue: raw) else { return nil }
        return action
    }

    /// Sets the action for a gesture in a specific zone.
    func setZoneAction(for gestureId: String, zone: TrackpadZone, action: KeySynthesizer.Action) {
        UserDefaults.standard.set(action.rawValue, forKey: "zones.\(gestureId).\(zone.rawValue)")
        objectWillChange.send()
    }

    // MARK: - Shortcut Names

    /// Returns the Apple Shortcuts name for a gesture.
    func shortcutName(for gestureId: String) -> String? {
        UserDefaults.standard.string(forKey: "shortcut.\(gestureId)")
    }

    /// Sets the Apple Shortcuts name for a gesture.
    func setShortcutName(for gestureId: String, name: String) {
        if name.isEmpty {
            UserDefaults.standard.removeObject(forKey: "shortcut.\(gestureId)")
        } else {
            UserDefaults.standard.set(name, forKey: "shortcut.\(gestureId)")
        }
        objectWillChange.send()
    }

    // MARK: - Cooldown

    /// Default cooldown durations by gesture type.
    static let defaultCooldowns: [String: TimeInterval] = {
        var map: [String: TimeInterval] = [:]
        // Taps get shorter cooldown, swipes/long-press get longer
        for info in all {
            let id = info.id
            if id.contains("Swipe") || id.contains("LongPress") || id.contains("Click") {
                map[id] = 0.5
            } else {
                map[id] = 0.3
            }
        }
        return map
    }()

    /// Cached cooldown enabled flag (UserDefaults `"cooldownEnabled"`).
    /// Protected by enabledLock.
    private var cachedCooldownEnabled: Bool = false

    /// Per-gesture cooldown override cache. Protected by enabledLock.
    private var perGestureCooldown: [String: TimeInterval] = [:]

    /// Whether cooldown is globally enabled.
    var cooldownEnabled: Bool {
        get {
            os_unfair_lock_lock(&enabledLock)
            let v = cachedCooldownEnabled
            os_unfair_lock_unlock(&enabledLock)
            return v
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "cooldownEnabled")
            os_unfair_lock_lock(&enabledLock)
            cachedCooldownEnabled = newValue
            os_unfair_lock_unlock(&enabledLock)
            objectWillChange.send()
        }
    }

    /// Returns the cooldown duration for a gesture (per-gesture override or default).
    /// Clamped to 0.1–5.0 seconds to prevent degenerate values.
    func cooldownDuration(for gestureId: String) -> TimeInterval {
        os_unfair_lock_lock(&enabledLock)
        if let override = perGestureCooldown[gestureId] {
            os_unfair_lock_unlock(&enabledLock)
            return Self.clamp(override, 0.1, 5.0)
        }
        os_unfair_lock_unlock(&enabledLock)
        return Self.defaultCooldowns[gestureId] ?? 0.3
    }

    /// Sets a custom cooldown duration for a gesture.
    func setCooldownDuration(for gestureId: String, duration: TimeInterval) {
        os_unfair_lock_lock(&enabledLock)
        perGestureCooldown[gestureId] = duration
        os_unfair_lock_unlock(&enabledLock)
        UserDefaults.standard.set(duration, forKey: "cooldown.\(gestureId)")
    }

    /// Clears a per-gesture cooldown override (falls back to default).
    func clearCooldownDuration(for gestureId: String) {
        os_unfair_lock_lock(&enabledLock)
        perGestureCooldown.removeValue(forKey: gestureId)
        os_unfair_lock_unlock(&enabledLock)
        UserDefaults.standard.removeObject(forKey: "cooldown.\(gestureId)")
    }

    /// Loads per-gesture cooldown overrides from UserDefaults.
    private func loadCooldownOverrides() {
        for info in Self.all {
            if let val = UserDefaults.standard.object(forKey: "cooldown.\(info.id)") as? Double {
                perGestureCooldown[info.id] = val
            }
        }
    }

    // MARK: - Launch at Login

    /// Whether the app is registered to launch at login (backed by SMAppService).
    var launchAtLogin: Bool {
        get { LaunchAtLoginHelper.isEnabled }
        set {
            LaunchAtLoginHelper.setEnabled(newValue)
            objectWillChange.send()
        }
    }

    // MARK: - Typing Suppression (Palm Rejection)

    /// When true, gestures are suppressed while the user is typing on the keyboard.
    var typingSuppressionEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "typingSuppressionEnabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "typingSuppressionEnabled")
            refreshCache()
            objectWillChange.send()
        }
    }

    /// How long after the last keystroke to suppress gestures (seconds). Default 0.3s.
    var typingSuppressionWindow: Double {
        get { UserDefaults.standard.object(forKey: "typingSuppressionWindow") as? Double ?? 0.3 }
        set {
            UserDefaults.standard.set(newValue, forKey: "typingSuppressionWindow")
            refreshCache()
            objectWillChange.send()
        }
    }

    // MARK: - Sensitivity

    /// Multiplier for tap speed thresholds (higher = more lenient timing). Range: 0.5–2.0, default 1.0.
    var tapSpeedMultiplier: Double {
        get { UserDefaults.standard.object(forKey: "tapSpeedMultiplier") as? Double ?? 1.0 }
        set {
            UserDefaults.standard.set(newValue, forKey: "tapSpeedMultiplier")
            refreshCache()
            objectWillChange.send()
        }
    }

    /// Multiplier for swipe displacement thresholds (higher = need bigger swipe). Range: 0.5–2.0, default 1.0.
    var swipeThresholdMultiplier: Double {
        get { UserDefaults.standard.object(forKey: "swipeThresholdMultiplier") as? Double ?? 1.0 }
        set {
            UserDefaults.standard.set(newValue, forKey: "swipeThresholdMultiplier")
            refreshCache()
            objectWillChange.send()
        }
    }

    /// Multiplier for move/drift thresholds (higher = more drift tolerance). Range: 0.5–2.0, default 1.0.
    var moveThresholdMultiplier: Double {
        get { UserDefaults.standard.object(forKey: "moveThresholdMultiplier") as? Double ?? 1.0 }
        set {
            UserDefaults.standard.set(newValue, forKey: "moveThresholdMultiplier")
            refreshCache()
            objectWillChange.send()
        }
    }

    // MARK: - Per-Frame Snapshot

    /// The current frame's sensitivity snapshot (set by GestureEngine at frame start).
    /// Reading this avoids individual lock acquisitions in each recognizer.
    /// Only written under engineLock (touch callback), only read under engineLock (recognizers).
    var frameSnapshot = SensitivitySnapshot(tapSpeed: 1.0, swipeMultiplier: 1.0, moveMultiplier: 1.0)

    /// Per-frame cache of the current app's disabled gesture set.
    /// Avoids acquiring appOverridesLock on every isEnabled() call.
    /// Only written/read under engineLock (touch callback thread).
    private(set) var frameAppOverrides: Set<String>?

    /// Updates frameSnapshot from cached values (call once per touch frame under engineLock).
    func updateFrameSnapshot() {
        os_unfair_lock_lock(&enabledLock)
        frameSnapshot = SensitivitySnapshot(
            tapSpeed: cachedTapSpeed,
            swipeMultiplier: cachedSwipeMultiplier,
            moveMultiplier: cachedMoveMultiplier
        )
        let bundleId = _cachedFrontmostBundleId
        os_unfair_lock_unlock(&enabledLock)

        // Snapshot current app's overrides (single appOverridesLock acquisition per frame)
        if let bundleId {
            os_unfair_lock_lock(&appOverridesLock)
            frameAppOverrides = cachedAppOverrides?[bundleId]
            os_unfair_lock_unlock(&appOverridesLock)
        } else {
            frameAppOverrides = nil
        }
    }

    // Effective threshold values — read from frameSnapshot (no individual locking needed).
    // These are called from recognizers under engineLock after updateFrameSnapshot().

    /// Effective tap duration (base 0.25s × tapSpeed)
    var effectiveMaxTapDuration: TimeInterval { frameSnapshot.maxTapDuration() }

    /// Effective double-tap window (base 0.40s × tapSpeed)
    var effectiveDoubleTapWindow: TimeInterval { frameSnapshot.doubleTapWindow() }

    /// Effective multi-tap window (base 0.35s × tapSpeed)
    var effectiveMultiTapWindow: TimeInterval { frameSnapshot.multiTapWindow() }

    /// Effective hold stability duration (base 0.10s × tapSpeed)
    var effectiveHoldStability: TimeInterval { frameSnapshot.holdStability() }

    /// Effective long press duration (base × tapSpeed)
    func effectiveLongPressDuration(base: Double) -> TimeInterval { frameSnapshot.longPressDuration(base: base) }

    /// Effective swipe threshold (base × swipeMultiplier)
    func effectiveSwipeThreshold(base: Float) -> Float { frameSnapshot.swipeThreshold(base: base) }

    /// Effective move threshold (base × moveMultiplier)
    func effectiveMoveThreshold(base: Float) -> Float { frameSnapshot.moveThreshold(base: base) }
}
