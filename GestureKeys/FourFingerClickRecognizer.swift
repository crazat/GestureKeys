import Foundation

/// Recognizes four-finger physical click on trackpad.
/// Short click → toggle fullscreen (⌃⌘F). Force Touch click → hide app (⌘H).
///
/// State machine:
/// ```
/// [Idle] → 4 active touches → [FourDown]
/// [FourDown] + physical click (if forceClick enabled) → [ClickHeld]
/// [FourDown] + physical click (if forceClick disabled) → fire normal → [Cooldown]
/// [ClickHeld] + fingers lift → fire normal click → [Cooldown]
/// [ClickHeld] + Force Touch pressure detected → fire force click → [Cooldown]
/// [ClickHeld] + timeout (2s) → fire normal click → [Cooldown]
/// [FourDown] + 5+ fingers → [Idle]
/// [FourDown] + fingers < 4 → [Idle] (after grace period)
/// [Cooldown] (200ms) → [Idle]
/// ```
final class FourFingerClickRecognizer {

    enum State {
        case idle
        case fourDown
        case clickHeld
        case cooldown
    }

    private(set) var state: State = .idle

    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.05) }
    private let cooldownDuration: TimeInterval = 0.2
    private let gracePeriod: TimeInterval = 0.200

    // MARK: - Force Touch Constants

    /// Time after click to let pressure stabilize before Force Touch detection.
    private let stabilizationDuration: TimeInterval = 0.15

    /// Force Touch fires when max pressure exceeds basePressure × this multiplier.
    private let forceTouchMultiplier: Float = 1.5

    /// Safety timeout: if clickHeld exceeds this, fire normal click to prevent stuck state.
    private let clickHeldTimeout: TimeInterval = 2.0

    // MARK: - Tracking State

    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]
    private var cooldownStart: TimeInterval = 0
    private var clickHeldStart: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private(set) var activeTouchCount: Int = 0

    /// Peak pressure recorded during stabilization window (normal click baseline).
    private var basePressure: Float = 0
    private var didLogStabilization: Bool = false

    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) {
        activeTouchCount = activeTouches.count

        switch state {
        case .idle:
            if activeTouches.count == 4 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                dropTime = 0
                state = .fourDown
            }

        case .fourDown:
            if activeTouches.count > 4 {
                state = .idle
                return
            }
            if activeTouches.count < 4 {
                if dropTime == 0 { dropTime = timestamp }
                else if timestamp - dropTime > gracePeriod { state = .idle }
                return
            }
            dropTime = 0
            if hasExcessiveMovement(activeTouches, initialPositions: initialPositions, threshold: moveThreshold) {
                state = .idle
            }

        case .clickHeld:
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = now - clickHeldStart

            // Fingers lifted → fire normal click
            if activeTouches.count < 4 {
                fireNormalClick()
                return
            }

            // 5+ fingers → cancel
            if activeTouches.count > 4 {
                state = .idle
                return
            }

            let maxPressure = activeTouches.map(\.pressure).max() ?? 0

            // Phase 1: Stabilization (first 150ms after click)
            if elapsed < stabilizationDuration {
                if maxPressure > basePressure {
                    basePressure = maxPressure
                }
                return
            }

            if !didLogStabilization {
                didLogStabilization = true
                NSLog("GestureKeys: 4FC stabilized base pressure: %.2f", basePressure)
            }

            // Phase 2: Force Touch detection
            let forceTouchDetected = basePressure > 0
                && maxPressure > basePressure * forceTouchMultiplier

            if forceTouchDetected {
                NSLog("GestureKeys: 4FC Force Touch fired! base=%.2f current=%.2f (×%.2f)",
                      basePressure, maxPressure, maxPressure / basePressure)
                if GestureConfig.shared.isEnabled("fourFingerLongClick") {
                    KeySynthesizer.fireAction(gestureId: "fourFingerLongClick")
                    state = .cooldown
                    cooldownStart = now
                } else {
                    fireNormalClick()
                }
                return
            }

            // Safety timeout
            if elapsed >= clickHeldTimeout {
                fireNormalClick()
            }

        case .cooldown:
            if timestamp - cooldownStart >= cooldownDuration {
                state = .idle
            }
        }
    }

    enum ClickResult {
        case none
        case fired
        case clickHeld
    }

    /// Called by GestureEngine when a physical click is detected.
    func handlePhysicalClick() -> ClickResult {
        guard state == .fourDown else { return .none }

        // If force click gesture is enabled, defer to detect Force Touch pressure
        if GestureConfig.shared.isEnabled("fourFingerLongClick") {
            state = .clickHeld
            clickHeldStart = ProcessInfo.processInfo.systemUptime
            basePressure = 0
            didLogStabilization = false
            return .clickHeld
        }

        return fireNormalClick() ? .fired : .none
    }

    @discardableResult
    private func fireNormalClick() -> Bool {
        guard GestureConfig.shared.isEnabled("fourFingerClick") else {
            state = .idle
            return false
        }

        KeySynthesizer.fireAction(gestureId: "fourFingerClick")
        state = .cooldown
        cooldownStart = ProcessInfo.processInfo.systemUptime
        return true
    }

    func reset() {
        state = .idle
        initialPositions.removeAll(keepingCapacity: true)
        activeTouchCount = 0
        dropTime = 0
        cooldownStart = 0
        clickHeldStart = 0
        basePressure = 0
        didLogStabilization = false
    }
}
