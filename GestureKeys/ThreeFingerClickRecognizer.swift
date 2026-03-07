import Foundation

/// Recognizes three-finger physical click on trackpad.
/// Short click → close tab (Cmd+W). Long hold click → quit app (Cmd+Q).
///
/// State machine:
/// ```
/// [Idle] → 3 active touches → [ThreeDown]
/// [ThreeDown] + physical click (if longClick enabled) → [ClickHeld]
/// [ThreeDown] + physical click (if longClick disabled) → fire normal → [Cooldown]
/// [ClickHeld] + fingers lift before holdDuration → fire normal click → [Cooldown]
/// [ClickHeld] + holdDuration elapsed with fingers still down → fire long click → [Cooldown]
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

            // Held long enough → fire long click (quit app)
            if now - clickHeldStart >= holdDuration {
                if GestureConfig.shared.isEnabled("threeFingerLongClick") {
                    KeySynthesizer.fireAction(gestureId: "threeFingerLongClick")
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
        case none          // not in threeDown state
        case fired         // normal click fired (suppress leftMouseDown)
        case clickHeld     // waiting for hold duration (suppress leftMouseDown)
    }

    /// Called by GestureEngine when a physical click is detected via CGEventTap.
    func handlePhysicalClick() -> ClickResult {
        guard state == .threeDown else { return .none }

        // If long click gesture is enabled, defer to measure hold duration
        if GestureConfig.shared.isEnabled("threeFingerLongClick") {
            state = .clickHeld
            clickHeldStart = ProcessInfo.processInfo.systemUptime
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
    }
}
