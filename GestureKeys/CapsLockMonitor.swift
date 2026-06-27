import Foundation
import IOKit.hid
import os

/// Global IOHIDManager input-value callback (must be a C function — cannot capture).
/// Fires on every raw Caps Lock report from any matched keyboard.
private func capsLockHIDCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard result == kIOReturnSuccess else { return }
    let element = IOHIDValueGetElement(value)
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    guard usagePage == UInt32(kHIDPage_KeyboardOrKeypad),
          usage == UInt32(kHIDUsage_KeyboardCapsLock) else { return }
    // Raw HID reports 1 on physical press, 0 on release — with NO driver debounce,
    // so we see fast taps the EventTap-level flagsChanged would silently drop.
    // Toggle on key-down only.
    guard IOHIDValueGetIntegerValue(value) != 0 else { return }
    CapsLockMonitor.handleCapsDown()
}

/// Captures the physical Caps Lock key at the raw HID level via IOHIDManager,
/// bypassing the ~250ms debounce the macOS keyboard driver adds to Caps Lock on
/// built-in keyboards. This is the only way to make fast Caps Lock taps register
/// reliably — at the EventTap (flagsChanged) level the debounced event never arrives.
///
/// Requires Input Monitoring permission (`kIOHIDRequestTypeListenEvent`). The
/// EventTap still consumes the (delayed) flagsChanged event to suppress the actual
/// caps-lock effect; this monitor only provides the instant input-source toggle.
final class CapsLockMonitor {
    static let shared = CapsLockMonitor()
    private init() {}

    private var manager: IOHIDManager?
    private var lock = os_unfair_lock()
    private var _running = false
    private var lastCapsDownTime: TimeInterval = 0
    private let duplicatePressWindow: TimeInterval = 0.08

    /// Thread-safe. Read from the EventTap callback so the slow EventTap path knows
    /// not to ALSO toggle (it must only consume) while this monitor is live.
    var isRunning: Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _running
    }

    /// Current Input Monitoring access status.
    static func accessGranted() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Triggers the Input Monitoring permission prompt if status is undetermined.
    @discardableResult
    static func requestAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Invoked from the HID callback on each physical Caps Lock key-down.
    static func handleCapsDown() {
        shared.handleCapsDown()
    }

    private func handleCapsDown() {
        let snapshot = GestureConfig.shared.capsLockSnapshot
        guard snapshot.inputSwitch, snapshot.fastSwitch else { return }

        let now = ProcessInfo.processInfo.systemUptime
        os_unfair_lock_lock(&lock)
        if now - lastCapsDownTime < duplicatePressWindow {
            os_unfair_lock_unlock(&lock)
            return
        }
        lastCapsDownTime = now
        os_unfair_lock_unlock(&lock)

        if !KeySynthesizer.postToggleInputSource() {
            os_unfair_lock_lock(&lock)
            lastCapsDownTime = 0
            os_unfair_lock_unlock(&lock)
        }
    }

    /// Starts or stops the monitor to match the current setting + permission state.
    /// Safe to call repeatedly (e.g. from engine start, settings toggle, permission grant).
    func refresh() {
        let snapshot = GestureConfig.shared.capsLockSnapshot
        let wanted = snapshot.inputSwitch && snapshot.fastSwitch
        if wanted && Self.accessGranted() {
            start()
        } else {
            stop()
        }
    }

    func start() {
        os_unfair_lock_lock(&lock)
        let alreadyRunning = _running
        os_unfair_lock_unlock(&lock)
        guard !alreadyRunning else { return }

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        // Match keyboards only…
        let deviceMatch: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(mgr, deviceMatch as CFDictionary)
        // …and within them, deliver only the Caps Lock element's value changes.
        let valueMatch: [String: Any] = [
            kIOHIDElementUsagePageKey: kHIDPage_KeyboardOrKeypad,
            kIOHIDElementUsageKey: kHIDUsage_KeyboardCapsLock
        ]
        IOHIDManagerSetInputValueMatching(mgr, valueMatch as CFDictionary)
        IOHIDManagerRegisterInputValueCallback(mgr, capsLockHIDCallback, nil)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let status = IOHIDManagerOpen(mgr, 0)
        guard status == kIOReturnSuccess else {
            NSLog("GestureKeys: CapsLockMonitor open failed (status=0x%X) — Input Monitoring permission likely missing", status)
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            return
        }

        os_unfair_lock_lock(&lock)
        manager = mgr
        _running = true
        os_unfair_lock_unlock(&lock)
        NSLog("GestureKeys: CapsLockMonitor started (fast Caps Lock 한영전환)")
    }

    func stop() {
        os_unfair_lock_lock(&lock)
        let mgr = manager
        let was = _running
        manager = nil
        _running = false
        os_unfair_lock_unlock(&lock)

        guard let mgr, was else { return }
        IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(mgr, 0)
        NSLog("GestureKeys: CapsLockMonitor stopped")
    }
}
