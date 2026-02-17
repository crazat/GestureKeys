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
            Info(id: "fourFingerClick",       name: "네 손가락 클릭",             action: "전체화면 토글 (⌃⌘F)",        defaultEnabled: true,
                 howTo: "네 손가락을 트랙패드에 올린 뒤, 물리적으로 트랙패드를 꾹 눌러 클릭하세요."),
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
        ]),
        Category(id: "editing", title: "편집", icon: "pencil", gestures: [
            Info(id: "twoFingerDoubleTap",   name: "두 손가락 더블탭",            action: "복사 (⌘C)",                  defaultEnabled: true,
                 howTo: "두 손가락을 동시에 빠르게 두 번 탭하세요."),
            Info(id: "threeFingerDoubleTap", name: "세 손가락 더블탭",            action: "붙여넣기 (⌘V)",              defaultEnabled: true,
                 howTo: "세 손가락을 동시에 빠르게 두 번 탭하세요."),
            Info(id: "threeFingerLongPress", name: "세 손가락 길게 누르기",        action: "실행 취소 (⌘Z)",             defaultEnabled: true,
                 howTo: "세 손가락을 트랙패드에 올리고 0.5초 이상 움직이지 않고 유지하세요."),
            Info(id: "twhLeftLongPress",     name: "홀드 + 왼쪽 길게 누르기",     action: "다시 실행 (⇧⌘Z)",            defaultEnabled: false,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 왼쪽에서 세 번째 손가락을 0.3초 이상 누르고 있으세요."),
            Info(id: "twhRightLongPress",    name: "홀드 + 오른쪽 길게 누르기",   action: "저장 (⌘S)",                  defaultEnabled: false,
                 howTo: "두 손가락을 트랙패드에 올려 유지한 뒤, 오른쪽에서 세 번째 손가락을 0.3초 이상 누르고 있으세요."),
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
            Info(id: "fourFingerLongPress",  name: "네 손가락 길게 누르기",       action: "화면 캡처 UI (⇧⌘5)",         defaultEnabled: false,
                 howTo: "네 손가락을 트랙패드에 올리고 0.5초 이상 움직이지 않고 유지하세요."),
            Info(id: "fiveFingerTap",        name: "다섯 손가락 탭",             action: "잠금화면 (⌃⌘Q)",             defaultEnabled: false,
                 howTo: "다섯 손가락을 동시에 트랙패드에 올렸다가 빠르게 떼세요. 0.4초 이내에 완료해야 합니다."),
            Info(id: "fiveFingerClick",      name: "다섯 손가락 클릭",           action: "앱 종료 (⌘Q)",               defaultEnabled: false,
                 howTo: "다섯 손가락을 트랙패드에 올린 뒤, 물리적으로 트랙패드를 꾹 눌러 클릭하세요."),
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

    /// Cached frontmost app bundle ID (updated by GestureEngine on main thread under lock).
    /// Read from touch callback thread under the same lock — thread-safe.
    var cachedFrontmostBundleId: String?

    /// Last frontmost bundle ID that wasn't GestureKeys itself.
    /// Used by AppOverrideView "현재 앱" button to avoid capturing our own app.
    var lastExternalBundleId: String?

    /// Cached multiplier values for hot-path reads (updated on settings change).
    private(set) var cachedTapSpeed: Double = 1.0
    private(set) var cachedSwipeMultiplier: Double = 1.0
    private(set) var cachedMoveMultiplier: Double = 1.0
    private(set) var cachedTypingSupprEnabled: Bool = true
    private(set) var cachedTypingSupprWindow: Double = 0.3

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
    }

    /// Clamps a value to a valid range.
    private static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, value))
    }

    /// Refreshes cached values from UserDefaults (with bounds validation).
    func refreshCache() {
        cachedTapSpeed = Self.clamp(UserDefaults.standard.object(forKey: "tapSpeedMultiplier") as? Double ?? 1.0, 0.5, 2.0)
        cachedSwipeMultiplier = Self.clamp(UserDefaults.standard.object(forKey: "swipeThresholdMultiplier") as? Double ?? 1.0, 0.5, 2.0)
        cachedMoveMultiplier = Self.clamp(UserDefaults.standard.object(forKey: "moveThresholdMultiplier") as? Double ?? 1.0, 0.5, 2.0)
        cachedTypingSupprEnabled = UserDefaults.standard.object(forKey: "typingSuppressionEnabled") as? Bool ?? true
        cachedTypingSupprWindow = Self.clamp(UserDefaults.standard.object(forKey: "typingSuppressionWindow") as? Double ?? 0.3, 0.1, 1.0)
    }

    // MARK: - API

    /// Thread-safe read from in-memory cache (no UserDefaults I/O).
    /// Also checks per-app overrides for the frontmost application.
    func isEnabled(_ id: String) -> Bool {
        os_unfair_lock_lock(&enabledLock)
        let globalEnabled = enabledCache[id] ?? (Self.defaultEnabledMap[id] ?? false)
        os_unfair_lock_unlock(&enabledLock)
        guard globalEnabled else { return false }

        // Check per-app override (uses cached bundleId, updated by GestureEngine under lock)
        if let bundleId = cachedFrontmostBundleId,
           let overrides = appOverrides[bundleId],
           overrides.contains(id) {
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

    // MARK: - Action Remapping

    /// Returns the action assigned to a gesture (default or remapped).
    /// Reads from in-memory cache (no UserDefaults I/O or string allocation).
    func actionFor(_ gestureId: String) -> KeySynthesizer.Action {
        actionCache[gestureId] ?? KeySynthesizer.defaultActions[gestureId] ?? .cmdW
    }

    /// Sets a remapped action for a gesture.
    func setAction(_ gestureId: String, _ action: KeySynthesizer.Action) {
        actionCache[gestureId] = action
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
    private(set) var cachedHudEnabled: Bool = false
    private(set) var cachedHapticEnabled: Bool = true

    var hudEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "hudEnabled") as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: "hudEnabled")
            cachedHudEnabled = newValue
            objectWillChange.send()
        }
    }

    var hapticEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "hapticEnabled")
            cachedHapticEnabled = newValue
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

    // Effective threshold values (thread-safe reads from UserDefaults)

    /// Effective tap duration (base 0.25s × cachedTapSpeed)
    var effectiveMaxTapDuration: TimeInterval {
        0.250 * cachedTapSpeed
    }

    /// Effective double-tap window (base 0.40s × cachedTapSpeed)
    var effectiveDoubleTapWindow: TimeInterval {
        0.400 * cachedTapSpeed
    }

    /// Effective multi-tap window (base 0.35s × cachedTapSpeed)
    var effectiveMultiTapWindow: TimeInterval {
        0.350 * cachedTapSpeed
    }

    /// Effective hold stability duration (base 0.10s × cachedTapSpeed)
    var effectiveHoldStability: TimeInterval {
        0.100 * cachedTapSpeed
    }

    /// Effective long press duration (base × cachedTapSpeed)
    func effectiveLongPressDuration(base: Double) -> TimeInterval {
        base * cachedTapSpeed
    }

    /// Effective swipe threshold (base × cachedSwipeMultiplier)
    func effectiveSwipeThreshold(base: Float) -> Float {
        base * Float(cachedSwipeMultiplier)
    }

    /// Effective move threshold (base × cachedMoveMultiplier)
    func effectiveMoveThreshold(base: Float) -> Float {
        base * Float(cachedMoveMultiplier)
    }
}
