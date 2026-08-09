import AppKit
import CoreGraphics

// MARK: - Global State (required for @convention(c) callbacks)

/// Lock protecting access to the engine instance from callback threads
private var engineLock = os_unfair_lock()

/// Singleton engine instance, accessed from C callbacks
private var engineInstance: GestureEngine?

/// Global multitouch callback function (cannot capture context).
/// Uses UnsafeMutableRawPointer because MTTouch isn't directly representable in @convention(c).
private func touchCallback(
    device: MTDeviceRef,
    rawTouches: UnsafeMutableRawPointer,
    touchCount: Int32,
    timestamp: Double,
    frame: Int32
) {
    os_unfair_lock_lock(&engineLock)
    guard let engine = engineInstance, engine.acceptsCallbacks else {
        os_unfair_lock_unlock(&engineLock)
        return
    }
    // Record on systemUptime (not the MT frame timestamp) so device recovery can
    // cross-reference it against lastTrackpadInputTime, which is also systemUptime.
    engine.lastTouchCallbackTime = ProcessInfo.processInfo.systemUptime
    os_unfair_lock_unlock(&engineLock)

    let touches = rawTouches.assumingMemoryBound(to: MTTouch.self)
    engine.processTouches(touches, count: Int(touchCount), timestamp: timestamp)
}

// MARK: - NX_SYSDEFINED Constants

/// CGEventType raw value for system-defined events (media keys, brightness, etc.)
private let kNXEventTypeSysDefined: UInt32 = 14

/// NSEvent subtype for special key events (media, brightness, illumination)
private let kNXSubtypeSpecialKey: Int16 = 8

/// NX key type constants (extracted from data1 field: `(data1 >> 16) & 0xFF`)
private let kNXKeyTypeBrightnessUp: Int = 2
private let kNXKeyTypeBrightnessDown: Int = 3

/// Key event state masks within data1
private let kNXKeyStateDown: Int = 0x0A00
private let kNXKeyStateMask: Int = 0xFF00

/// Global CGEventTap callback for intercepting mouse clicks
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Handle tap being disabled by the system.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        os_unfair_lock_lock(&engineLock)
        let engine = engineInstance?.acceptsCallbacks == true ? engineInstance : nil
        os_unfair_lock_unlock(&engineLock)
        engine?.reEnableEventTap()
        engine?.trackTapDisabled()
        return Unmanaged.passUnretained(event)
    }

    // Safe engine reference via engineLock (avoids use-after-free during shutdown)
    os_unfair_lock_lock(&engineLock)
    guard let engine = engineInstance, engine.acceptsCallbacks else {
        os_unfair_lock_unlock(&engineLock)
        return Unmanaged.passUnretained(event)
    }
    os_unfair_lock_unlock(&engineLock)

    // Shift + brightness key → keyboard backlight (no lock needed)
    if type.rawValue == kNXEventTypeSysDefined {
        if event.flags.contains(.maskShift),
           let nsEvent = NSEvent(cgEvent: event),
           nsEvent.subtype.rawValue == kNXSubtypeSpecialKey {
            let data1 = nsEvent.data1
            let keyType = (data1 >> 16) & 0xFF
            if keyType == kNXKeyTypeBrightnessUp || keyType == kNXKeyTypeBrightnessDown {
                let isDown = (data1 & kNXKeyStateMask) == kNXKeyStateDown
                if isDown {
                    if keyType == kNXKeyTypeBrightnessUp {
                        KeySynthesizer.postKbBrightnessUp()
                    } else {
                        KeySynthesizer.postKbBrightnessDown()
                    }
                }
                return nil  // consume both down and up
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // Caps Lock → instant input source toggle (before typing suppression)
    if type == .flagsChanged && event.getIntegerValueField(.keyboardEventKeycode) == 0x39 {
        if GestureConfig.shared.capsLockInputSwitch {
            // Fast path: when the IOHIDManager monitor is live it already toggled the
            // input source on the raw key-down (no ~250ms debounce, no dropped fast
            // taps). Here we only consume the delayed flagsChanged so the caps-lock
            // effect is suppressed — toggling again would double-switch.
            if CapsLockMonitor.shared.isRunning {
                return nil
            }
            // Slow path (no Input Monitoring permission / fast switch off):
            // Detect flag STATE TRANSITION instead of time-based debounce.
            // Caps Lock is a toggle modifier: pressing it changes .maskAlphaShift,
            // but releasing does NOT change it. By only toggling on transitions,
            // we naturally ignore key-up events regardless of hold duration.
            let capsLockOn = event.flags.contains(.maskAlphaShift)
            os_unfair_lock_lock(&engineLock)
            let lastState = engine.lastCapsLockFlagState
            os_unfair_lock_unlock(&engineLock)

            if lastState == nil || capsLockOn != lastState {
                let didSwitch = KeySynthesizer.postToggleInputSource()
                os_unfair_lock_lock(&engineLock)
                engine.lastCapsLockFlagState = didSwitch ? capsLockOn : nil
                os_unfair_lock_unlock(&engineLock)
            }
            return nil  // Consume Caps Lock event
        }
    }

    // Track keyboard events for precise typing suppression
    if type == .keyDown || type == .flagsChanged {
        let now = ProcessInfo.processInfo.systemUptime
        let timeSinceSynthesis = now - KeySynthesizer.lastSynthesisTimestamp
        // Only record if this event was NOT generated by our own key synthesis
        if timeSinceSynthesis > 0.05 {
            os_unfair_lock_lock(&engineLock)
            engine.lastExternalKeyTime = now
            // Typing burst tracking
            let burstWindow: TimeInterval = 2.0
            if now - engine.burstStartTime > burstWindow {
                engine.keystrokeCount = 1
                engine.burstStartTime = now
                engine.typingBurstActive = false
            } else {
                engine.keystrokeCount += 1
                if engine.keystrokeCount >= 5 {
                    engine.typingBurstActive = true
                }
            }
            os_unfair_lock_unlock(&engineLock)
        }
        return Unmanaged.passUnretained(event)
    }

    // Suppress scroll events while 3+ fingers are active or after a 3-finger swipe fired.
    // macOS generates scroll events from finger movement during 3-finger gestures,
    // and momentum scroll continues for up to ~2s after fingers lift.
    if type == .scrollWheel {
        // Liveness probe: a continuous, non-momentum scroll means fingers are
        // physically scrolling on the trackpad right now. If the MT contact
        // callback is alive it MUST be firing concurrently — device recovery
        // cross-references this against lastTouchCallbackTime to detect a dead
        // MultitouchSupport callback thread while the device count is unchanged.
        let isContinuousScroll = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let scrollMomentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        os_unfair_lock_lock(&engineLock)
        if isContinuousScroll && scrollMomentumPhase == 0 {
            engine.lastTrackpadInputTime = ProcessInfo.processInfo.systemUptime
        }
        let touchCount = engine.currentTouchCount
        let timeSinceSwipe = ProcessInfo.processInfo.systemUptime - engine.lastSwipeFireTime
        os_unfair_lock_unlock(&engineLock)
        // Suppress during 3+ finger contact
        if touchCount >= 3 {
            return nil
        }
        // Suppress momentum scroll after swipe fire (phase 0 = user scroll, non-zero = momentum)
        if timeSinceSwipe < 2.0 {
            let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            // Suppress all scroll for first 0.3s, then only momentum scroll up to 2s
            if timeSinceSwipe < 0.3 || momentumPhase != 0 {
                return nil
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .leftMouseDown else {
        return Unmanaged.passUnretained(event)
    }

    os_unfair_lock_lock(&engineLock)
    var shouldSuppress = false

    // 5-finger click has highest priority (most fingers, least ambiguous)
    shouldSuppress = engine.fiveFingerClickRecognizer.handlePhysicalClick()
    if shouldSuppress {
        // 5FC consumed the click — reset competing 5-finger and 4-finger recognizers
        engine.fiveFingerTapRecognizer.reset()
        engine.fiveFingerLongPressRecognizer.reset()
        engine.fourFingerDoubleTapRecognizer.reset()
        engine.fourFingerLongPressRecognizer.reset()
    }

    // 4-finger click
    if !shouldSuppress {
        let fourClickResult = engine.fourFingerRecognizer.handlePhysicalClick()
        if fourClickResult == .fired || fourClickResult == .clickHeld {
            shouldSuppress = true
            if fourClickResult == .clickHeld {
                // Reset competing 4-finger recognizers during hold
                engine.fourFingerDoubleTapRecognizer.reset()
                engine.fourFingerLongPressRecognizer.reset()
            }
        }
    }

    if !shouldSuppress {
        // Skip 3FC when a while-holding recognizer has confirmed a hold+action pattern.
        // Hold detection requires 2 fingers stable for 100ms+ before the 3rd arrives,
        // clearly distinguishing from a simultaneous 3-finger click.
        let holdPatternActive = engine.tapWhileHoldingRecognizer.isActive
            || engine.swipeWhileHoldingRecognizer.isActive
            || engine.longPressWhileHoldingRecognizer.isActive

        if !holdPatternActive {
            let clickResult = engine.threeFingerRecognizer.handlePhysicalClick()
            if clickResult == .fired {
                shouldSuppress = true
                // 3FC consumed the click — reset all competing recognizers
                engine.tapWhileHoldingRecognizer.reset()
                engine.swipeWhileHoldingRecognizer.reset()
                engine.longPressWhileHoldingRecognizer.reset()
                engine.threeFingerDoubleTapRecognizer.reset()
                engine.threeFingerTripleTapRecognizer.reset()
                engine.threeFingerLongPressRecognizer.reset()
                engine.threeFingerSwipeRecognizer.reset()
            } else if clickResult == .clickHeld {
                shouldSuppress = true
                // clickHeld: physical click differentiates from long press (no click).
                // Reset all competing recognizers including long press.
                engine.tapWhileHoldingRecognizer.reset()
                engine.swipeWhileHoldingRecognizer.reset()
                engine.longPressWhileHoldingRecognizer.reset()
                engine.threeFingerDoubleTapRecognizer.reset()
                engine.threeFingerTripleTapRecognizer.reset()
                engine.threeFingerLongPressRecognizer.reset()
                engine.threeFingerSwipeRecognizer.reset()
            }
        }
    }
    let pendingActions = KeySynthesizer.takePendingActions()
    os_unfair_lock_unlock(&engineLock)
    for action in pendingActions { action() }

    if shouldSuppress {
        return nil
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - GestureEngine

/// Central orchestrator that manages multitouch device lifecycle,
/// routes touch data to gesture recognizers, and manages the CGEventTap.
final class GestureEngine {

    // MARK: Notifications

    /// Posted when CGEventTap creation fails at startup.
    static let eventTapFailedNotification = Notification.Name("GestureKeysEventTapFailed")

    /// Posted when the system repeatedly disables the EventTap (likely stale permission).
    static let permissionIssueNotification = Notification.Name("GestureKeysPermissionIssue")

    /// Posted when no multitouch devices are found at startup.
    static let noDevicesNotification = Notification.Name("GestureKeysNoDevices")

    /// Posted when the EventTap has been successfully restored after a failure.
    static let eventTapRestoredNotification = Notification.Name("GestureKeysEventTapRestored")

    /// When true, gestures are recognized but not executed (test mode).
    private static var monitorModeStorage = false
    private static var monitorModeLock = os_unfair_lock()
    static var monitorMode: Bool {
        get {
            os_unfair_lock_lock(&monitorModeLock)
            let value = monitorModeStorage
            os_unfair_lock_unlock(&monitorModeLock)
            return value
        }
        set {
            os_unfair_lock_lock(&monitorModeLock)
            monitorModeStorage = newValue
            os_unfair_lock_unlock(&monitorModeLock)
        }
    }

    /// True if CGEventTap was successfully installed.
    private(set) var eventTapActive = false

    let threeFingerRecognizer = ThreeFingerClickRecognizer()
    let fourFingerRecognizer = FourFingerClickRecognizer()
    let tapWhileHoldingRecognizer = TapWhileHoldingRecognizer()
    let swipeWhileHoldingRecognizer = SwipeWhileHoldingRecognizer()
    let longPressWhileHoldingRecognizer = LongPressWhileHoldingRecognizer()
    let threeFingerDoubleTapRecognizer = ThreeFingerDoubleTapRecognizer()
    let threeFingerTripleTapRecognizer = ThreeFingerTripleTapRecognizer()
    let threeFingerLongPressRecognizer = ThreeFingerLongPressRecognizer()
    let fourFingerDoubleTapRecognizer = FourFingerDoubleTapRecognizer()
    let fourFingerLongPressRecognizer = FourFingerLongPressRecognizer()
    let fiveFingerTapRecognizer = FiveFingerTapRecognizer()
    let fiveFingerClickRecognizer = FiveFingerClickRecognizer()
    let fiveFingerLongPressRecognizer = FiveFingerLongPressRecognizer()
    let threeFingerSwipeRecognizer = ThreeFingerSwipeRecognizer()
    let oneFingerHoldTapRecognizer = OneFingerHoldTapRecognizer()
    let oneFingerHoldSwipeRecognizer = OneFingerHoldSwipeRecognizer()
    let twoFingerSwipeRecognizer = TwoFingerSwipeRecognizer()
    let twoFingerTapRecognizer = TwoFingerTapRecognizer()

    /// Deferred double-tap work item (scheduled when triple-tap is enabled).
    private var deferredDoubleTapItem: DispatchWorkItem?

    /// Protected by engineLock — prevents deferred double-tap from firing after triple-tap.
    private var deferredDoubleTapCancelled = false

    private var devices: [MTDeviceRef] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    fileprivate var acceptsCallbacks = false
    private var deviceRecoveryTimer: Timer?
    private var eventTapHealthTimer: Timer?
    private var eventTapRetryTimer: Timer?
    private var eventTapRetryCount = 0
    private let maxEventTapRetries = 5
    private var pendingDeviceStartItem: DispatchWorkItem?
    private var pendingEventTapRecoveryItem: DispatchWorkItem?
    private var deviceStartGeneration = 0
    private var eventTapRecoveryGeneration = 0
    private var lastSystemWakeRecoveryTime: TimeInterval = 0

    /// Activity token that prevents App Nap from throttling timers and callbacks.
    /// Without this, macOS suspends menu bar apps (LSUIElement, no visible windows)
    /// after idle, causing EventTap callbacks to time out and health-check timers
    /// to stop firing — silently disabling all gestures.
    private var appNapActivity: NSObjectProtocol?

    /// True when Mission Control, Exposé, or Spaces transition is active.
    /// Updated on main thread via workspace notification; read from touch callback.
    private var systemUIActive = false

    /// Timestamp of the last externally-generated keyboard event (not our synthesis).
    /// Updated in the CGEventTap callback under `engineLock`. Used for typing suppression.
    fileprivate var lastExternalKeyTime: TimeInterval = 0
    /// Current number of active touches, updated under engineLock by processTouches.
    fileprivate var currentTouchCount: Int = 0
    /// Timestamp when a 3-finger swipe last fired, used to suppress post-fire scroll momentum.
    fileprivate var lastSwipeFireTime: TimeInterval = 0

    /// Tracks whether 4/5-finger gesture was recently in .fired state.
    /// Used to reset 3-finger recognizers once when transitioning from fired → idle.
    private var wasHighFingerFired = false

    /// When true, 4-finger recognizers are suppressed until all fingers lift.
    /// Set when 5-finger contact is detected; cleared when activeCount == 0.
    private var suppressFourFinger = false

    /// Number of keystrokes in the current typing burst (for burst detection).
    fileprivate var keystrokeCount: Int = 0

    /// Timestamp of the first keystroke in the current burst window.
    fileprivate var burstStartTime: TimeInterval = 0

    /// True when a typing burst has been detected (extends suppression window).
    fileprivate var typingBurstActive = false

    /// Last observed Caps Lock flag state (nil = not yet observed). Protected by engineLock.
    /// Used to detect flag TRANSITIONS rather than time-based debounce.
    /// Key insight: Caps Lock is a toggle modifier — pressing it changes the
    /// `.maskAlphaShift` flag, but releasing does NOT change it. By only toggling
    /// input source on flag transitions, we naturally ignore key-up events
    /// regardless of how long the user holds the key.
    fileprivate var lastCapsLockFlagState: Bool?

    /// Tracks timestamps of consecutive tapDisabledByTimeout events for S3 detection.
    private var tapDisabledTimestamps: [TimeInterval] = []

    /// Timestamp of the last successful EventTap reinstall (cooldown dedup).
    private var lastReinstallTime: TimeInterval = 0

    /// Timestamp of the last multitouch callback invocation. Protected by engineLock.
    /// Used by device recovery to detect silent callback death (device handle stale
    /// but count unchanged, or MultitouchSupport internal thread died).
    fileprivate var lastTouchCallbackTime: TimeInterval = 0

    /// Timestamp of the last physical trackpad scroll seen by the EventTap (continuous,
    /// non-momentum). Protected by engineLock. Proves the trackpad hardware is alive
    /// independently of the MT contact callback — the cross-reference that detects a
    /// dead MT callback thread without false-firing during idle.
    fileprivate var lastTrackpadInputTime: TimeInterval = 0

    /// Timestamp of the last device re-registration (cooldown to avoid tight re-register
    /// loops when recovery doesn't immediately revive the callback). Protected by engineLock.
    private var lastDeviceReregisterTime: TimeInterval = 0

    /// Prevents duplicate permission issue alerts.
    private var permissionIssuePosted = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Verify MTTouch struct layout matches MultitouchSupport.framework
        _ = MTTouch._sizeCheck

        // Prevent App Nap: macOS aggressively suspends menu bar apps (LSUIElement,
        // no visible windows) when idle, which throttles Timer firing and delays
        // EventTap callback processing. This causes tapDisabledByTimeout and
        // silently kills gesture recognition.
        //
        // Use `.userInitiatedAllowingIdleSystemSleep` rather than `.userInitiated`:
        // the latter implies `.idleSystemSleepDisabled`, which would keep the Mac
        // awake forever — wrong for a background gesture app. We allow the system to
        // idle-sleep normally; sleep/wake recovery (handleWake + health check) brings
        // gestures back afterward.
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "GestureKeys must process trackpad events in real time"
        )

        os_unfair_lock_lock(&engineLock)
        engineInstance = self
        acceptsCallbacks = true
        os_unfair_lock_unlock(&engineLock)

        startMultitouchDevices()
        installEventTap()
        startDeviceRecovery()
        startEventTapHealthCheck()
        observeSystemUI()
        observeScreenLock()
        KeySynthesizer.startObservingInputSourceChanges()
        KeySynthesizer.prewarmInputSourceCache()
        CapsLockMonitor.shared.refresh()

        NSLog("GestureKeys: Engine started with %d device(s)", devices.count)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        os_unfair_lock_lock(&engineLock)
        acceptsCallbacks = false
        engineInstance = nil
        os_unfair_lock_unlock(&engineLock)

        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        deviceRecoveryTimer?.invalidate()
        deviceRecoveryTimer = nil
        eventTapHealthTimer?.invalidate()
        eventTapHealthTimer = nil
        eventTapRetryTimer?.invalidate()
        eventTapRetryTimer = nil
        pendingDeviceStartItem?.cancel()
        pendingDeviceStartItem = nil
        pendingEventTapRecoveryItem?.cancel()
        pendingEventTapRecoveryItem = nil
        deviceStartGeneration += 1
        eventTapRecoveryGeneration += 1
        // Order matters: remove event tap first so callbacks can't fire on stopped devices.
        removeEventTap()
        stopMultitouchDevices()
        CapsLockMonitor.shared.stop()
        KeySynthesizer.invalidateInputSourceCache()

        os_unfair_lock_lock(&engineLock)
        engineInstance = nil
        deferredDoubleTapItem?.cancel()
        deferredDoubleTapItem = nil
        deferredDoubleTapCancelled = true
        lastCapsLockFlagState = nil
        eventTapRetryCount = 0
        wasHighFingerFired = false
        MacroEngine.shared.reset()
        resetAllRecognizers()
        os_unfair_lock_unlock(&engineLock)

        // Release App Nap prevention
        appNapActivity = nil

        NSLog("GestureKeys: Engine stopped")
    }

    /// Resets all gesture recognizers to idle state.
    /// Must be called while `engineLock` is held.
    private func resetAllRecognizers() {
        suppressFourFinger = false
        threeFingerRecognizer.reset()
        fourFingerRecognizer.reset()
        tapWhileHoldingRecognizer.reset()
        swipeWhileHoldingRecognizer.reset()
        longPressWhileHoldingRecognizer.reset()
        threeFingerDoubleTapRecognizer.reset()
        threeFingerTripleTapRecognizer.reset()
        threeFingerLongPressRecognizer.reset()
        fourFingerDoubleTapRecognizer.reset()
        fourFingerLongPressRecognizer.reset()
        fiveFingerTapRecognizer.reset()
        fiveFingerClickRecognizer.reset()
        fiveFingerLongPressRecognizer.reset()
        threeFingerSwipeRecognizer.reset()
        oneFingerHoldTapRecognizer.reset()
        oneFingerHoldSwipeRecognizer.reset()
        twoFingerSwipeRecognizer.reset()
        twoFingerTapRecognizer.reset()
    }

    /// Timestamp of the last reEnableEventTap log (throttle to every 5 seconds).
    private var lastReEnableLogTime: TimeInterval = 0

    /// Re-enables the event tap if the system disabled it.
    /// Thread-safe: captures eventTap reference under engineLock.
    func reEnableEventTap() {
        os_unfair_lock_lock(&engineLock)
        let tap = eventTap
        let now = ProcessInfo.processInfo.systemUptime
        var shouldLog = false
        if now - lastReEnableLogTime > 5.0 {
            lastReEnableLogTime = now
            shouldLog = true
        }
        os_unfair_lock_unlock(&engineLock)

        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            if shouldLog {
                NSLog("GestureKeys: Event tap re-enabled")
            }
        }
    }

    /// Completely removes and recreates the EventTap.
    /// Called when repeated re-enable attempts fail (stale permission after reboot/rebuild).
    /// Thread-safe: reads eventTapActive under engineLock after reinstall.
    private func reinstallEventTap() {
        // Cooldown: skip if reinstalled within the last 3 seconds.
        // Multiple async paths (handleWake +2s, handleScreenUnlocked +1s,
        // healthCheck 5s) can all trigger reinstall within a short window.
        // Without dedup, each reinstall tears down the working EventTap
        // and recreates it, causing brief gesture-dead gaps.
        let now = ProcessInfo.processInfo.systemUptime
        os_unfair_lock_lock(&engineLock)
        if now - lastReinstallTime < 3.0 {
            let elapsed = now - lastReinstallTime
            os_unfair_lock_unlock(&engineLock)
            NSLog("GestureKeys: Skipping EventTap reinstall — cooldown active (%.1fs ago)", elapsed)
            return
        }
        lastReinstallTime = now
        os_unfair_lock_unlock(&engineLock)

        NSLog("GestureKeys: Attempting EventTap reinstall...")
        removeEventTap()
        installEventTap()

        os_unfair_lock_lock(&engineLock)
        let active = eventTapActive
        os_unfair_lock_unlock(&engineLock)

        if active {
            NSLog("GestureKeys: EventTap reinstall succeeded")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.eventTapRestoredNotification, object: nil)
            }
        } else {
            NSLog("GestureKeys: EventTap reinstall failed — falling back to notification")
        }
    }

    /// Tracks repeated tapDisabledByTimeout events.
    /// If 3+ disables within 10 seconds, the permission is likely stale (rebuild).
    /// Automatically attempts EventTap reinstall before escalating to user notification.
    /// Thread-safe: accesses tapDisabledTimestamps/permissionIssuePosted under engineLock.
    func trackTapDisabled() {
        let now = ProcessInfo.processInfo.systemUptime

        os_unfair_lock_lock(&engineLock)
        tapDisabledTimestamps.append(now)
        // Keep only events within the last 10 seconds (in-place removal avoids allocation)
        tapDisabledTimestamps.removeAll { now - $0 >= 10.0 }
        let shouldReinstall = tapDisabledTimestamps.count >= 3 && !permissionIssuePosted
        let count = tapDisabledTimestamps.count
        os_unfair_lock_unlock(&engineLock)

        if shouldReinstall {
            NSLog("GestureKeys: EventTap disabled %d times in 10s — attempting reinstall", count)
            reinstallEventTap()
            // If reinstall failed, escalate to user notification
            os_unfair_lock_lock(&engineLock)
            let active = eventTapActive
            if !active {
                permissionIssuePosted = true
            }
            os_unfair_lock_unlock(&engineLock)
            if !active {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.permissionIssueNotification, object: nil)
                }
            }
        }
    }

    // MARK: - Touch Processing

    func processTouches(_ touchPtr: UnsafeMutablePointer<MTTouch>, count: Int, timestamp: Double) {
        guard count > 0 else { return }
        // Single-pass filter from raw buffer (1 allocation instead of 2)
        let activeTouches = UnsafeBufferPointer(start: touchPtr, count: count).filter { $0.touchState.isActive }
        let activeCount = activeTouches.count

        if Self.monitorMode {
            GestureMonitor.shared.updateTouchCount(activeCount)
            GestureMonitor.shared.logTouchSizes(activeTouches)
            GestureMonitor.shared.recordHeatmapPositions(activeTouches)
        }

        // Deferred double-tap scheduling flags (set under lock, used after unlock)
        var scheduleDeferred = false
        var cancelDeferred = false
        var deferDelay: TimeInterval = 0.4

        os_unfair_lock_lock(&engineLock)
        guard acceptsCallbacks else {
            os_unfair_lock_unlock(&engineLock)
            return
        }

        currentTouchCount = activeCount

        // Pre-compute typing suppression values (used in 3 suppression checks below)
        let config = GestureConfig.shared

        // Snapshot sensitivity multipliers once per frame (replaces ~50 individual lock/unlock cycles)
        config.updateFrameSnapshot()

        // Suppress gestures during Mission Control / Exposé / Spaces transition
        if systemUIActive {
            resetAllRecognizers()
            os_unfair_lock_unlock(&engineLock)
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let timeSinceTyping = now - lastExternalKeyTime
        // Snapshot typing suppression settings under enabledLock (written from main thread)
        let typingSupprEnabled = config.typingSuppressionSnapshot.enabled
        let typingSupprWindow = config.typingSuppressionSnapshot.window
        let hasPeripheralTouch = typingSupprEnabled
            && activeTouches.contains { $0.isTypingEdge || $0.isPalmSized }

        // Typing suppression (palm rejection): zone-aware.
        // Only suppress peripheral/palm touches during typing window.
        if typingSupprEnabled {
            let baseWindow = typingSupprWindow
            let window = typingBurstActive ? max(baseWindow, 0.4) : baseWindow

            if timeSinceTyping < window && hasPeripheralTouch {
                resetAllRecognizers()
                os_unfair_lock_unlock(&engineLock)
                return
            }

            // Decay burst state after sustained silence
            if timeSinceTyping > 3.0 {
                typingBurstActive = false
                keystrokeCount = 0
            }
        }
        // 2-finger hold recognizers: suppress peripheral/palm touches during extended typing window
        let twoFingerSuppressed = hasPeripheralTouch
            && timeSinceTyping < max(typingSupprWindow * 1.2, 0.4)

        processClickRecognizers(activeTouches, activeCount: activeCount, timestamp: timestamp)
        processHoldRecognizers(activeTouches, activeCount: activeCount, timestamp: timestamp, suppressed: twoFingerSuppressed)
        processThreeFingerGestures(activeTouches, activeCount: activeCount, timestamp: timestamp,
                                   config: config, scheduleDeferred: &scheduleDeferred,
                                   cancelDeferred: &cancelDeferred, deferDelay: &deferDelay)
        processFourFingerGestures(activeTouches, activeCount: activeCount, timestamp: timestamp)
        processFiveFingerGestures(activeTouches, activeCount: activeCount, timestamp: timestamp)
        processOneFingerGestures(activeTouches, timestamp: timestamp,
                                hasPeripheralTouch: hasPeripheralTouch,
                                timeSinceTyping: timeSinceTyping, typingSupprWindow: typingSupprWindow)
        processTwoFingerGestures(activeTouches, timestamp: timestamp, suppressed: twoFingerSuppressed)
        // Deferred double-tap scheduling (under lock — cancel/create are lightweight)
        if cancelDeferred {
            deferredDoubleTapItem?.cancel()
            deferredDoubleTapItem = nil
        }
        if scheduleDeferred {
            deferredDoubleTapItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                os_unfair_lock_lock(&engineLock)
                guard let self = self, engineInstance != nil, !self.deferredDoubleTapCancelled else {
                    os_unfair_lock_unlock(&engineLock)
                    return
                }
                self.deferredDoubleTapCancelled = true  // prevent re-firing
                if GestureConfig.shared.isEnabled("threeFingerDoubleTap") {
                    KeySynthesizer.fireAction(gestureId: "threeFingerDoubleTap")
                }
                let deferredActions = KeySynthesizer.takePendingActions()
                os_unfair_lock_unlock(&engineLock)
                for action in deferredActions { action() }
            }
            deferredDoubleTapItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + deferDelay, execute: item)
        }

        let pendingActions = KeySynthesizer.takePendingActions()
        os_unfair_lock_unlock(&engineLock)
        for action in pendingActions { action() }
    }

    // MARK: - Recognizer Groups (called under engineLock)

    /// Click-based recognizers (3FC, 4FC, 5FC) — physical trackpad click detection.
    private func processClickRecognizers(_ activeTouches: [MTTouch], activeCount: Int, timestamp: Double) {
        if activeCount >= 3 || threeFingerRecognizer.state != .idle {
            threeFingerRecognizer.processTouches(activeTouches, timestamp: timestamp)
        }
        if activeCount >= 4 || fourFingerRecognizer.state != .idle {
            fourFingerRecognizer.processTouches(activeTouches, timestamp: timestamp)
        }
        if activeCount >= 5 || fiveFingerClickRecognizer.state != .idle {
            fiveFingerClickRecognizer.processTouches(activeTouches, timestamp: timestamp)
        }
    }

    /// Two-finger hold + action recognizers (TWH, SWH, LPWH).
    private func processHoldRecognizers(_ activeTouches: [MTTouch], activeCount: Int,
                                        timestamp: Double, suppressed: Bool) {
        if suppressed {
            tapWhileHoldingRecognizer.reset()
            swipeWhileHoldingRecognizer.reset()
            longPressWhileHoldingRecognizer.reset()
        } else {
            tapWhileHoldingRecognizer.processTouches(activeTouches, timestamp: timestamp)

            let swipeFired = swipeWhileHoldingRecognizer.processTouches(activeTouches, timestamp: timestamp)
            if swipeFired {
                tapWhileHoldingRecognizer.reset()
                longPressWhileHoldingRecognizer.reset()
            }

            let longPressFired = longPressWhileHoldingRecognizer.processTouches(activeTouches, timestamp: timestamp)
            if longPressFired {
                tapWhileHoldingRecognizer.reset()
                swipeWhileHoldingRecognizer.reset()
            }
        }
    }

    /// Three-finger gestures (swipe, double-tap, triple-tap, long-press) with deferred double-tap logic.
    /// 3FC (click) has highest priority — never reset by other 3-finger recognizers.
    private func processThreeFingerGestures(_ activeTouches: [MTTouch], activeCount: Int,
                                            timestamp: Double, config: GestureConfig,
                                            scheduleDeferred: inout Bool,
                                            cancelDeferred: inout Bool,
                                            deferDelay: inout TimeInterval) {
        // Track 4/5-finger .fired state transitions.
        // Reset 3-finger recognizers once when high-finger gesture ends,
        // clearing partial state accumulated during finger lift.
        let highFingerFired = fourFingerLongPressRecognizer.state == .fired
            || fiveFingerLongPressRecognizer.state == .fired
        if highFingerFired {
            wasHighFingerFired = true
        } else if wasHighFingerFired {
            // Transition: fired → not fired. Reset 3-finger recognizers once.
            wasHighFingerFired = false
            threeFingerDoubleTapRecognizer.reset()
            threeFingerTripleTapRecognizer.reset()
            threeFingerLongPressRecognizer.reset()
            threeFingerSwipeRecognizer.reset()
        }

        guard activeCount >= 3
            || threeFingerDoubleTapRecognizer.state != .idle
            || threeFingerTripleTapRecognizer.state != .idle
            || threeFingerLongPressRecognizer.state != .idle
            || threeFingerSwipeRecognizer.state != .idle else { return }

        let swipeWasFired = threeFingerSwipeRecognizer.state == .fired
        let threeFingerSwipeFired = threeFingerSwipeRecognizer.processTouches(activeTouches, timestamp: timestamp)
        if threeFingerSwipeFired {
            lastSwipeFireTime = ProcessInfo.processInfo.systemUptime
        }
        // Reset competing recognizers when swipe fires, stays in .fired, or just left .fired
        // (the transition frame where .fired→.idle must also suppress doubleTap)
        if threeFingerSwipeFired || threeFingerSwipeRecognizer.state == .fired || swipeWasFired {
            threeFingerDoubleTapRecognizer.reset()
            threeFingerTripleTapRecognizer.reset()
            // Long press not reset here — it self-resets via its own movement check (0.03)
        }

        let tripleTapFired = threeFingerTripleTapRecognizer.processTouches(activeTouches, timestamp: timestamp)

        let tripleEnabled = config.isEnabled("threeFingerTripleTap")
        threeFingerDoubleTapRecognizer.suppressFire = tripleEnabled && threeFingerTripleTapRecognizer.state == .secondTapUp
        threeFingerDoubleTapRecognizer.processTouches(activeTouches, timestamp: timestamp)
        threeFingerDoubleTapRecognizer.suppressFire = false

        if threeFingerDoubleTapRecognizer.didSuppressFire {
            threeFingerDoubleTapRecognizer.didSuppressFire = false
            deferredDoubleTapCancelled = false
            scheduleDeferred = true
            deferDelay = config.effectiveDoubleTapWindow
        }

        if tripleTapFired {
            deferredDoubleTapCancelled = true
            cancelDeferred = true
            threeFingerDoubleTapRecognizer.reset()
        }

        // Skip long press when click recognizer is in clickHeld — physical click differentiates
        if threeFingerRecognizer.state != .clickHeld {
            threeFingerLongPressRecognizer.processTouches(activeTouches, timestamp: timestamp)
        }
        if threeFingerLongPressRecognizer.state == .fired {
            threeFingerDoubleTapRecognizer.reset()
            threeFingerTripleTapRecognizer.reset()
            threeFingerSwipeRecognizer.reset()
        }
    }

    /// Four-finger gestures (double-tap, long-press).
    private func processFourFingerGestures(_ activeTouches: [MTTouch], activeCount: Int, timestamp: Double) {
        // Suppress 4-finger gestures during and after 5-finger contact.
        // Once 5 fingers are detected, 4-finger recognizers stay suppressed
        // until ALL fingers lift — prevents false 4-finger fires from
        // finger lift transitions (5→4) or firedTimeout expiry.
        if activeCount >= 5
            || fiveFingerLongPressRecognizer.state != .idle
            || fiveFingerTapRecognizer.state != .idle
            || fiveFingerClickRecognizer.state != .idle {
            suppressFourFinger = true
        }
        if suppressFourFinger {
            fourFingerDoubleTapRecognizer.reset()
            fourFingerLongPressRecognizer.reset()
            if activeCount == 0 { suppressFourFinger = false }
            return
        }

        guard activeCount >= 4
            || fourFingerDoubleTapRecognizer.state != .idle
            || fourFingerLongPressRecognizer.state != .idle else { return }

        fourFingerDoubleTapRecognizer.processTouches(activeTouches, timestamp: timestamp)
        // Skip long press when click recognizer is in clickHeld — physical click differentiates
        if fourFingerRecognizer.state != .clickHeld {
            fourFingerLongPressRecognizer.processTouches(activeTouches, timestamp: timestamp)
        }
        if fourFingerLongPressRecognizer.state == .fired {
            fourFingerDoubleTapRecognizer.reset()
        }
    }

    /// Five-finger gestures (tap, long-press) + deferred display sleep.
    private func processFiveFingerGestures(_ activeTouches: [MTTouch], activeCount: Int, timestamp: Double) {
        // Suppress 5FLP/5FT while 5FC is waiting for Force Touch
        let fiveClickHeld = fiveFingerClickRecognizer.state == .clickHeld

        if activeCount >= 5 || fiveFingerTapRecognizer.state != .idle || fiveFingerLongPressRecognizer.state != .idle {
            if fiveClickHeld {
                fiveFingerTapRecognizer.reset()
                fiveFingerLongPressRecognizer.reset()
            } else {
                let tapFired = fiveFingerTapRecognizer.processTouches(activeTouches, timestamp: timestamp)
                fiveFingerLongPressRecognizer.processTouches(activeTouches, timestamp: timestamp)
                if tapFired {
                    fiveFingerClickRecognizer.reset()
                    fiveFingerLongPressRecognizer.reset()
                    fourFingerLongPressRecognizer.reset()
                    fourFingerDoubleTapRecognizer.reset()
                }
                if fiveFingerLongPressRecognizer.state == .fired {
                    fiveFingerTapRecognizer.reset()
                    fiveFingerClickRecognizer.reset()
                    fourFingerLongPressRecognizer.reset()
                    fourFingerDoubleTapRecognizer.reset()
                }
            }
        }

        // Deferred display sleep: execute after fingers lift to prevent trackpad wake
        if fiveFingerLongPressRecognizer.consumeLiftEvent() {
            KeySynthesizer.appendPendingAction { KeySynthesizer.postSleepDisplay() }
        }
    }

    /// One-finger hold + tap/swipe recognizers.
    private func processOneFingerGestures(_ activeTouches: [MTTouch], timestamp: Double,
                                          hasPeripheralTouch: Bool,
                                          timeSinceTyping: TimeInterval,
                                          typingSupprWindow: Double) {
        let suppressed = hasPeripheralTouch && timeSinceTyping < max(typingSupprWindow * 1.5, 0.5)

        if suppressed {
            oneFingerHoldTapRecognizer.reset()
            oneFingerHoldSwipeRecognizer.reset()
        } else {
            oneFingerHoldTapRecognizer.lastExternalKeyTime = lastExternalKeyTime
            oneFingerHoldSwipeRecognizer.lastExternalKeyTime = lastExternalKeyTime
            oneFingerHoldTapRecognizer.processTouches(activeTouches, timestamp: timestamp)
            let ofhSwipeFired = oneFingerHoldSwipeRecognizer.processTouches(activeTouches, timestamp: timestamp)
            if ofhSwipeFired {
                oneFingerHoldTapRecognizer.reset()
            }
        }
    }

    /// Two-finger standalone recognizers (swipe, double-tap).
    private func processTwoFingerGestures(_ activeTouches: [MTTouch], timestamp: Double, suppressed: Bool) {
        if suppressed {
            twoFingerSwipeRecognizer.reset()
            twoFingerTapRecognizer.reset()
        } else {
            let twoFingerSwipeFired = twoFingerSwipeRecognizer.processTouches(activeTouches, timestamp: timestamp)
            if twoFingerSwipeFired {
                oneFingerHoldTapRecognizer.reset()
                oneFingerHoldSwipeRecognizer.reset()
                twoFingerTapRecognizer.reset()
            }
            twoFingerTapRecognizer.processTouches(activeTouches, timestamp: timestamp)
        }
    }

    // MARK: - Multitouch Device Management

    private func startMultitouchDevices() {
        // Defensively unregister any existing callbacks to prevent double-registration.
        // This guards against overlapping async paths (e.g., handleWake + deviceRecoveryTimer
        // both scheduling startMultitouchDevices within a short window).
        if !devices.isEmpty {
            for device in devices {
                MTUnregisterContactFrameCallback(device, touchCallback)
            }
            devices.removeAll()
        }

        guard let rawList = MTDeviceCreateList() else {
            NSLog("GestureKeys: MTDeviceCreateList returned nil")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.noDevicesNotification, object: nil)
            }
            return
        }
        let count = CFArrayGetCount(rawList)

        if count == 0 {
            NSLog("GestureKeys: No multitouch devices found")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.noDevicesNotification, object: nil)
            }
            return
        }

        for i in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(rawList, i) else { continue }
            let device = MTDeviceRef(rawPtr)
            MTRegisterContactFrameCallback(device, touchCallback)
            let result = MTDeviceStart(device, 0)
            if result != 0 {
                NSLog("GestureKeys: MTDeviceStart failed for device %d: error %d", i, result)
                MTUnregisterContactFrameCallback(device, touchCallback)
                continue
            }
            devices.append(device)
        }
    }

    private func stopMultitouchDevices() {
        for device in devices {
            MTUnregisterContactFrameCallback(device, touchCallback)
            _ = MTDeviceStop(device)
        }
        devices.removeAll()
    }

    // MARK: - CGEventTap Management


    private func installEventTap() {
        eventTapRetryTimer?.invalidate()
        eventTapRetryTimer = nil

        // CGEvent.tapCreate is a system call — keep outside lock
        var eventMask: CGEventMask = 0
        eventMask |= (1 << CGEventType.leftMouseDown.rawValue)
        eventMask |= (1 << CGEventType.keyDown.rawValue)
        eventMask |= (1 << CGEventType.flagsChanged.rawValue)
        eventMask |= (1 << CGEventType.scrollWheel.rawValue)
        eventMask |= (1 << kNXEventTypeSysDefined)  // NX_SYSDEFINED
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: nil
        )

        guard let tap = tap else {
            os_unfair_lock_lock(&engineLock)
            eventTapActive = false
            eventTapRetryCount += 1
            let retryCount = eventTapRetryCount
            os_unfair_lock_unlock(&engineLock)

            if retryCount <= maxEventTapRetries {
                NSLog("GestureKeys: CGEventTap creation failed — retry %d/%d in 2s", retryCount, maxEventTapRetries)
                let timer = Timer(timeInterval: 2.0, repeats: false) { [weak self] _ in
                    guard let self, self.isRunning else { return }
                    self.installEventTap()
                }
                RunLoop.main.add(timer, forMode: .common)
                eventTapRetryTimer = timer
            } else {
                NSLog("GestureKeys: CGEventTap creation failed after %d retries", maxEventTapRetries)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.eventTapFailedNotification, object: nil)
                }
            }
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        os_unfair_lock_lock(&engineLock)
        eventTapRetryCount = 0
        eventTap = tap
        runLoopSource = source
        eventTapActive = true
        permissionIssuePosted = false
        tapDisabledTimestamps.removeAll()
        os_unfair_lock_unlock(&engineLock)

        NSLog("GestureKeys: CGEventTap created successfully")
    }

    private func removeEventTap() {
        os_unfair_lock_lock(&engineLock)
        let source = runLoopSource
        let tap = eventTap
        runLoopSource = nil
        eventTap = nil
        eventTapActive = false
        os_unfair_lock_unlock(&engineLock)

        if let source = source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            // Invalidate the Mach port so the system fully releases the event tap
            // registration. Without this, the old tap lingers at the system level
            // and can prevent a new tap from being created successfully.
            CFMachPortInvalidate(tap)
        }
    }

    // MARK: - System UI Detection

    private func observeSystemUI() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self, selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        // Also detect space changes (Spaces / full-screen transitions)
        center.addObserver(
            self, selector: #selector(activeAppChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
        // Sleep/wake handling: re-register devices and re-enable EventTap after wake
        center.addObserver(
            self, selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(handleSessionResume),
            name: NSWorkspace.screensDidWakeNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(handleSessionResume),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil
        )
    }

    /// Bundle IDs of system UI processes where gestures should be suppressed.
    private static let systemUIBundleIds: Set<String> = [
        "com.apple.dock",                    // Mission Control, Exposé, Spaces
        "com.apple.notificationcenterui",    // Notification Center, Stage Manager
        "com.apple.controlcenter",           // Control Center overlay
    ]

    @objc private func activeAppChanged(_ notification: Notification) {
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isSystemUI = bundleId.map { Self.systemUIBundleIds.contains($0) } ?? false
        os_unfair_lock_lock(&engineLock)
        systemUIActive = isSystemUI
        if bundleId != "com.gesturekeys.app" {
            GestureConfig.shared.lastExternalBundleId = bundleId
        }
        GestureConfig.shared.cachedFrontmostBundleId = bundleId
        if isSystemUI { resetAllRecognizers() }
        os_unfair_lock_unlock(&engineLock)
    }

    // MARK: - Sleep / Wake

    @objc private func handleSleep(_ notification: Notification) {
        NSLog("GestureKeys: System going to sleep — resetting recognizers")

        // A recovery queued immediately before sleep must not run against device
        // handles that are becoming stale. The real wake notification schedules
        // fresh work after MultitouchSupport has settled.
        pendingDeviceStartItem?.cancel()
        pendingDeviceStartItem = nil
        pendingEventTapRecoveryItem?.cancel()
        pendingEventTapRecoveryItem = nil
        deviceStartGeneration += 1
        eventTapRecoveryGeneration += 1

        os_unfair_lock_lock(&engineLock)
        resetAllRecognizers()
        lastExternalKeyTime = 0
        typingBurstActive = false
        keystrokeCount = 0
        lastTouchCallbackTime = 0
        lastTrackpadInputTime = 0
        os_unfair_lock_unlock(&engineLock)
    }

    @objc private func handleWake(_ notification: Notification) {
        guard isRunning else { return }
        scheduleSystemWakeRecovery(reason: notification.name.rawValue)
    }

    /// Recovers both MultitouchSupport and the EventTap after an actual system
    /// sleep. Device handles may be stale here, so they are discarded without
    /// calling MTDeviceStop (which can race MultitouchSupport's wake cleanup).
    private func scheduleSystemWakeRecovery(reason: String) {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastSystemWakeRecoveryTime < 2.0 {
            NSLog("GestureKeys: Skipping duplicate system-wake recovery for %@ (%.1fs ago)",
                  reason, now - lastSystemWakeRecoveryTime)
            return
        }
        lastSystemWakeRecoveryTime = now

        NSLog("GestureKeys: System-wake recovery scheduled for %@", reason)
        clearStaleMultitouchRegistrations(resetRecognizers: true)
        scheduleDeviceStart(after: 1.5, reason: reason)
        scheduleEventTapRecovery(after: 2.0, reason: reason)
    }

    /// Screen wake/session activation is not proof that the Mac slept. Restarting
    /// MultitouchSupport for these notifications leaks an internal MT worker thread
    /// on every lock/unlock cycle because the still-live device is never stopped.
    /// The device watchdog separately handles a genuinely dead contact callback.
    private func scheduleSessionResumeRecovery(reason: String) {
        guard isRunning else { return }
        NSLog("GestureKeys: Session-resume recovery scheduled for %@", reason)
        scheduleEventTapRecovery(after: 1.0, reason: reason)
    }

    private func clearStaleMultitouchRegistrations(resetRecognizers: Bool) {
        os_unfair_lock_lock(&engineLock)
        if resetRecognizers {
            resetAllRecognizers()
        }
        lastTouchCallbackTime = 0
        lastTrackpadInputTime = 0
        os_unfair_lock_unlock(&engineLock)

        // Do not call MTDeviceStop on potentially stale handles after sleep.
        for device in devices {
            MTUnregisterContactFrameCallback(device, touchCallback)
        }
        devices.removeAll()
    }

    private func scheduleDeviceStart(after delay: TimeInterval, reason: String) {
        pendingDeviceStartItem?.cancel()
        deviceStartGeneration += 1
        let generation = deviceStartGeneration
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning, generation == self.deviceStartGeneration else { return }
            self.startMultitouchDevices()
            NSLog("GestureKeys: Re-registered %d multitouch device(s) after %@", self.devices.count, reason)
        }
        pendingDeviceStartItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func scheduleEventTapRecovery(after delay: TimeInterval, reason: String) {
        pendingEventTapRecoveryItem?.cancel()
        eventTapRecoveryGeneration += 1
        let generation = eventTapRecoveryGeneration
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning, generation == self.eventTapRecoveryGeneration else { return }
            self.reinstallEventTap()
            KeySynthesizer.prewarmInputSourceCache()
            CapsLockMonitor.shared.stop()
            CapsLockMonitor.shared.refresh()
            NSLog("GestureKeys: EventTap/InputSource recovery finished after %@", reason)
        }
        pendingEventTapRecoveryItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    // MARK: - Screen Lock / Unlock

    /// Observes screen lock/unlock via DistributedNotificationCenter.
    /// Screen lock is NOT the same as system sleep — it does not trigger
    /// willSleepNotification/didWakeNotification, but macOS can still disable
    /// the EventTap during screen lock. Without this, gestures silently die
    /// after screen lock/unlock cycles.
    private func observeScreenLock() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(
            self, selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc private func handleScreenUnlocked(_ notification: Notification) {
        scheduleSessionResumeRecovery(reason: notification.name.rawValue)
    }

    @objc private func handleSessionResume(_ notification: Notification) {
        scheduleSessionResumeRecovery(reason: notification.name.rawValue)
    }

    // MARK: - EventTap Health Check

    /// Periodically verifies the EventTap is still valid and enabled.
    /// Checks both Mach port validity AND tap enabled state. macOS can disable
    /// a tap (tapDisabledByTimeout) without invalidating the port — the previous
    /// check only caught port invalidation, missing the disabled-but-valid case.
    private func startEventTapHealthCheck() {
        // Run in .commonModes so the watchdog keeps firing during tracking run
        // loops (open menus, modal panels) — .default-mode timers stall there.
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }
            os_unfair_lock_lock(&engineLock)
            let tap = self.eventTap
            let active = self.eventTapActive
            os_unfair_lock_unlock(&engineLock)

            guard active, let tap = tap else {
                // Tap is down. If accessibility permission is present, revive it.
                // This covers every way the tap can end up dead-but-unreported:
                // exhausted install retries, a failed reinstall, or permission just
                // restored — no manual off/on toggle required.
                if AXIsProcessTrusted() {
                    os_unfair_lock_lock(&engineLock)
                    self.permissionIssuePosted = false
                    os_unfair_lock_unlock(&engineLock)
                    NSLog("GestureKeys: Health check found EventTap inactive with valid permission — reinstalling")
                    self.reinstallEventTap()
                }
                return
            }

            if !CFMachPortIsValid(tap) {
                NSLog("GestureKeys: EventTap Mach port invalidated — reinstalling")
                self.reinstallEventTap()
            } else if !CGEvent.tapIsEnabled(tap: tap) {
                NSLog("GestureKeys: EventTap disabled (port valid) — re-enabling")
                CGEvent.tapEnable(tap: tap, enable: true)
                // Verify re-enable worked; if not, full reinstall
                if !CGEvent.tapIsEnabled(tap: tap) {
                    NSLog("GestureKeys: Re-enable failed — reinstalling")
                    self.reinstallEventTap()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        eventTapHealthTimer = timer
    }

    // MARK: - Device Recovery

    private func startDeviceRecovery() {
        // .commonModes so recovery survives tracking run loops (see health check).
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }
            // MTDeviceCreateList() returns a CFArray?. In Swift, it's automatically
            // managed via toll-free bridging. The local binding ensures ARC releases
            // it when this closure scope exits.
            guard let rawList = MTDeviceCreateList() else { return }
            let currentCount = CFArrayGetCount(rawList)

            // 1) Device count changed (connect/disconnect): re-register.
            // Note: OpaquePointer comparison is unreliable here — MTDeviceCreateList()
            // may return new wrapper objects for the same physical device each call.
            // Only use device count changes as the trigger for this path.
            if currentCount != self.devices.count {
                NSLog("GestureKeys: Device count changed (%d → %ld), re-registering", self.devices.count, currentCount)
                self.reregisterDevices()
                return
            }

            // 2) Silent MT callback death (count unchanged). The documented failure
            //    mode: the MultitouchSupport contact callback stops firing after long
            //    uptime / sleep cycles while the device list looks unchanged. Detect
            //    it two independent ways:
            //    (a) a registered device reports it is no longer running, OR
            //    (b) the trackpad is physically active right now (continuous scroll
            //        seen by the EventTap) yet no contact frame has arrived — the
            //        callback thread is dead while the hardware is alive.
            let now = ProcessInfo.processInfo.systemUptime
            os_unfair_lock_lock(&engineLock)
            let lastCb = self.lastTouchCallbackTime
            let lastInput = self.lastTrackpadInputTime
            let lastReregister = self.lastDeviceReregisterTime
            os_unfair_lock_unlock(&engineLock)

            let callbackSilentDuringInput = lastInput > 0
                && (now - lastInput) < 3.0
                && (lastCb == 0 || lastInput - lastCb > 2.5)
            let deviceStopped = !self.devices.isEmpty
                && self.devices.contains { !MTDeviceIsRunning($0) }

            guard callbackSilentDuringInput || deviceStopped else { return }
            // Cooldown: don't tear down repeatedly while recovery settles.
            guard now - lastReregister > 10.0 else { return }
            NSLog("GestureKeys: MT callback appears dead (stopped=%@, silentDuringInput=%@) — re-registering",
                  deviceStopped ? "yes" : "no", callbackSilentDuringInput ? "yes" : "no")
            self.reregisterDevices()
        }
        RunLoop.main.add(timer, forMode: .common)
        deviceRecoveryTimer = timer
    }

    /// Tears down stale device registrations and recreates them after a short settle
    /// delay. Shared by the count-change and callback-death recovery paths.
    /// Must be called on the main thread (mutates `devices`).
    private func reregisterDevices() {
        os_unfair_lock_lock(&engineLock)
        lastDeviceReregisterTime = ProcessInfo.processInfo.systemUptime
        os_unfair_lock_unlock(&engineLock)
        clearStaleMultitouchRegistrations(resetRecognizers: true)
        scheduleDeviceStart(after: 1.5, reason: "device recovery")
    }
}
