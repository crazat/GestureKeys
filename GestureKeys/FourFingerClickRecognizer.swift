import Foundation

/// Recognizes four-finger physical click on trackpad.
/// Short click → toggle fullscreen (⌃⌘F). Long hold click → hide app (⌘H).
///
/// State machine:
/// ```
/// [Idle] → 4 active touches → [FourDown]
/// [FourDown] + physical click (if longClick enabled) → [ClickHeld]
/// [FourDown] + physical click (if longClick disabled) → fire normal → [Cooldown]
/// [ClickHeld] + fingers lift before holdDuration → fire normal click → [Cooldown]
/// [ClickHeld] + holdDuration elapsed with fingers still down → fire long click → [Cooldown]
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

    /// How long the user must hold after clicking to trigger long click action.
    private let holdDuration: TimeInterval = 0.5

    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]
    private var cooldownStart: TimeInterval = 0
    private var clickHeldStart: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private(set) var activeTouchCount: Int = 0

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

            // Held long enough → fire long click (hide app)
            if now - clickHeldStart >= holdDuration {
                if GestureConfig.shared.isEnabled("fourFingerLongClick") {
                    KeySynthesizer.fireAction(gestureId: "fourFingerLongClick")
                    state = .cooldown
                    cooldownStart = now
                } else {
                    fireNormalClick()
                }
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

        // If long click gesture is enabled, defer to measure hold duration
        if GestureConfig.shared.isEnabled("fourFingerLongClick") {
            state = .clickHeld
            clickHeldStart = ProcessInfo.processInfo.systemUptime
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
    }
}
