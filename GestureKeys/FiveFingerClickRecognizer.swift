import Foundation

/// Recognizes five-finger physical click → force quit (⌥⌘Esc).
/// Requires Force Touch (safety mechanism) — normal click is suppressed without action.
///
/// State machine:
/// ```
/// [Idle] → 5 active touches → [FiveDown]
/// [FiveDown] + physical click → [ClickHeld] (suppress click, wait for Force Touch)
/// [ClickHeld] + Force Touch pressure detected → fire force quit → [Cooldown]
/// [ClickHeld] + fingers lift → cancel (no action) → [Idle]
/// [ClickHeld] + timeout (2s) → cancel (no action) → [Idle]
/// [FiveDown] + 6+ fingers → [Idle]
/// [FiveDown] + fingers < 5 → [Idle]
/// [Cooldown] (200ms) → [Idle]
/// ```
final class FiveFingerClickRecognizer {

    enum State {
        case idle
        case fiveDown
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

    /// Safety timeout: cancel clickHeld without action if exceeded.
    private let clickHeldTimeout: TimeInterval = 2.0

    // MARK: - Tracking State

    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]
    private var cooldownStart: TimeInterval = 0
    private var clickHeldStart: TimeInterval = 0
    private var dropTime: TimeInterval = 0

    /// Peak pressure recorded during stabilization window.
    private var basePressure: Float = 0
    private var didLogStabilization: Bool = false

    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) {
        switch state {
        case .idle:
            if activeTouches.count == 5 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                dropTime = 0
                state = .fiveDown
            }

        case .fiveDown:
            if activeTouches.count > 5 {
                state = .idle
                return
            }
            if activeTouches.count < 5 {
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

            // Fingers lifted → cancel without action (safety: must Force Touch)
            if activeTouches.count < 5 {
                state = .idle
                return
            }

            let maxPressure = activeTouches.map(\.pressure).max() ?? 0

            // Phase 1: Stabilization
            if elapsed < stabilizationDuration {
                if maxPressure > basePressure {
                    basePressure = maxPressure
                }
                return
            }

            if !didLogStabilization {
                didLogStabilization = true
                NSLog("GestureKeys: 5FC stabilized base pressure: %.2f", basePressure)
            }

            // Phase 2: Force Touch detection — only way to fire
            let forceTouchDetected = basePressure > 0
                && maxPressure > basePressure * forceTouchMultiplier

            if forceTouchDetected {
                NSLog("GestureKeys: 5FC Force Touch fired! base=%.2f current=%.2f (×%.2f)",
                      basePressure, maxPressure, maxPressure / basePressure)
                if GestureConfig.shared.isEnabled("fiveFingerClick") {
                    KeySynthesizer.fireAction(gestureId: "fiveFingerClick")
                }
                state = .cooldown
                cooldownStart = now
                return
            }

            // Safety timeout: cancel without action
            if elapsed >= clickHeldTimeout {
                state = .idle
            }

        case .cooldown:
            if timestamp - cooldownStart >= cooldownDuration {
                state = .idle
            }
        }
    }

    /// Called by GestureEngine when a physical click is detected.
    /// Returns true if the click should be suppressed.
    func handlePhysicalClick() -> Bool {
        guard state == .fiveDown else { return false }
        guard GestureConfig.shared.isEnabled("fiveFingerClick") else {
            state = .idle
            return false
        }

        // Enter clickHeld — require Force Touch to actually fire the action
        state = .clickHeld
        clickHeldStart = ProcessInfo.processInfo.systemUptime
        basePressure = 0
        didLogStabilization = false
        return true
    }

    func reset() {
        state = .idle
        initialPositions.removeAll(keepingCapacity: true)
        dropTime = 0
        cooldownStart = 0
        clickHeldStart = 0
        basePressure = 0
        didLogStabilization = false
    }
}
