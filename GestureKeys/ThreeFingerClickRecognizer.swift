import Foundation

/// Recognizes three-finger physical click on trackpad.
/// Short click → close tab (Cmd+W). Force Touch click → quit app (Cmd+Q).
///
/// State machine:
/// ```
/// [Idle] → 3 active touches → [ThreeDown]
/// [ThreeDown] + physical click (if forceClick enabled) → [ClickHeld]
/// [ThreeDown] + physical click (if forceClick disabled) → fire normal → [Cooldown]
/// [ClickHeld] + fingers lift → fire normal click → [Cooldown]
/// [ClickHeld] + Force Touch pressure detected → fire force click → [Cooldown]
/// [ClickHeld] + timeout (2s) → fire normal click → [Cooldown]
/// [ThreeDown] + 4+ fingers → [Idle]
/// [ThreeDown] + fingers < 3 → [Idle] (after grace period)
/// [Cooldown] (200ms) → [Idle]
/// ```
final class ThreeFingerClickRecognizer {

    enum State {
        case idle
        case threeDown
        case clickHeld
        case cooldown
    }

    private(set) var state: State = .idle

    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.08) }
    private let cooldownDuration: TimeInterval = 0.2
    private let gracePeriod: TimeInterval = 0.200

    // MARK: - Force Touch Constants

    /// Time after click to let pressure stabilize before Force Touch detection.
    /// During this window, peak pressure is recorded as basePressure (normal click level).
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

    /// Whether the stabilization log has been emitted for the current clickHeld cycle.
    private var didLogStabilization: Bool = false

    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) {
        activeTouchCount = activeTouches.count

        switch state {
        case .idle:
            if activeTouches.count == 3 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                dropTime = 0
                state = .threeDown
            }

        case .threeDown:
            if activeTouches.count > 3 {
                state = .idle
                return
            }
            if activeTouches.count < 3 {
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
            if activeTouches.count < 3 {
                fireNormalClick()
                return
            }

            // 4+ fingers → cancel
            if activeTouches.count > 3 {
                state = .idle
                return
            }

            let maxPressure = activeTouches.map(\.pressure).max() ?? 0

            // Phase 1: Stabilization (first 150ms after click)
            // Track peak pressure to establish the "normal click" baseline.
            if elapsed < stabilizationDuration {
                if maxPressure > basePressure {
                    basePressure = maxPressure
                }
                return
            }

            // Log stabilized base pressure once
            if !didLogStabilization {
                didLogStabilization = true
                NSLog("GestureKeys: 3FC stabilized base pressure: %.2f", basePressure)
            }

            // Phase 2: Force Touch detection
            let forceTouchDetected = basePressure > 0
                && maxPressure > basePressure * forceTouchMultiplier

            if forceTouchDetected {
                NSLog("GestureKeys: Force Touch fired! base=%.2f current=%.2f (×%.2f)",
                      basePressure, maxPressure, maxPressure / basePressure)
                if GestureConfig.shared.isEnabled("threeFingerLongClick") {
                    KeySynthesizer.fireAction(gestureId: "threeFingerLongClick")
                    state = .cooldown
                    cooldownStart = now
                } else {
                    fireNormalClick()
                }
                return
            }

            // Safety timeout: prevent stuck clickHeld state
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
        case none          // not in threeDown state
        case fired         // normal click fired (suppress leftMouseDown)
        case clickHeld     // waiting for Force Touch (suppress leftMouseDown)
    }

    /// Called by GestureEngine when a physical click is detected via CGEventTap.
    func handlePhysicalClick() -> ClickResult {
        guard state == .threeDown else { return .none }

        // If force click gesture is enabled, defer to detect Force Touch pressure
        if GestureConfig.shared.isEnabled("threeFingerLongClick") {
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
        guard GestureConfig.shared.isEnabled("threeFingerClick") else {
            state = .idle
            return false
        }

        let config = GestureConfig.shared
        if config.zonesEnabled(for: "threeFingerClick") {
            let avgX = initialPositions.values.reduce(Float(0)) { $0 + $1.x } / max(Float(initialPositions.count), 1)
            let zone = TrackpadZone.from(x: avgX)
            if let zoneAction = config.zoneAction(for: "threeFingerClick", zone: zone) {
                KeySynthesizer.fireAction(gestureId: "threeFingerClick", action: { zoneAction.execute() })
            } else {
                KeySynthesizer.fireAction(gestureId: "threeFingerClick")
            }
        } else {
            KeySynthesizer.fireAction(gestureId: "threeFingerClick")
        }
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
