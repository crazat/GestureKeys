import Foundation

/// Recognizes one-finger hold + single tap with another finger for quick tab switching.
///
/// - Tap to the LEFT of the held finger → previous tab (⇧⌘[)
/// - Tap to the RIGHT of the held finger → next tab (⇧⌘])
///
/// Fires instantly when the tap finger lifts (no double-tap delay).
/// After firing, stays in holdDetected for rapid consecutive taps.
///
/// State machine:
/// ```
/// [Idle] → exactly 1 finger stable for 200ms → [HoldDetected]
/// [HoldDetected] → 2nd finger appears → [TapDown]
/// [TapDown] → 2nd finger lifts within 250ms → fire action → [HoldDetected]
/// [TapDown] → 2nd finger held > 250ms → [Idle] (probably a 2-finger gesture)
/// Any state → held finger lifts or moves excessively → [Idle]
/// ```
final class OneFingerHoldTapRecognizer {

    enum State {
        case idle
        case holdDetected
        case tapDown
    }

    private(set) var state: State = .idle

    private let holdDuration: TimeInterval = 0.100
    private var maxTapDuration: TimeInterval { GestureConfig.shared.effectiveMaxTapDuration }
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.05) }
    private let holdGracePeriod: TimeInterval = 0.080

    // Hold finger tracking
    private var tracking = false
    private var holdStartTime: TimeInterval = 0
    private var holdPathIndex: Int32 = -1
    private var holdInitialX: Float = 0
    private var holdInitialY: Float = 0
    private var holdDropTime: TimeInterval = 0

    // Tap finger tracking
    private var tapDownTime: TimeInterval = 0
    private var tapIsRight = false

    var isActive: Bool { state == .tapDown }

    /// How long ago the last external keystroke occurred (set by GestureEngine).
    var lastExternalKeyTime: TimeInterval = 0

    /// Dynamic touch rejection: strict zone during typing, permissive otherwise.
    private func isRejectedTouch(_ touch: MTTouch) -> Bool {
        if touch.isPalmSized { return true }
        let timeSinceTyping = ProcessInfo.processInfo.systemUptime - lastExternalKeyTime
        if timeSinceTyping < 2.0 {
            // Recently typed: use wide rejection zone (30% sides, 20% top)
            return touch.isTypingEdge
        } else {
            // Not typing: only reject extreme edge (3%)
            return touch.isEdgeTouch
        }
    }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            if activeCount == 1 {
                let finger = activeTouches[0]
                if isRejectedTouch(finger) {
                    tracking = false
                    return false
                }
                if !tracking || finger.pathIndex != holdPathIndex {
                    tracking = true
                    holdStartTime = timestamp
                    holdPathIndex = finger.pathIndex
                    holdInitialX = finger.normalizedVector.position.x
                    holdInitialY = finger.normalizedVector.position.y
                } else if hasExcessiveMovement(finger) {
                    holdStartTime = timestamp
                    holdInitialX = finger.normalizedVector.position.x
                    holdInitialY = finger.normalizedVector.position.y
                } else if timestamp - holdStartTime >= holdDuration {
                    state = .holdDetected
                    holdDropTime = 0
                }
            } else {
                tracking = false
            }
            return false

        case .holdDetected:
            guard let holdFound = activeTouches.first(where: { $0.pathIndex == holdPathIndex }) else {
                if holdDropTime == 0 {
                    holdDropTime = timestamp
                } else if timestamp - holdDropTime > holdGracePeriod {
                    reset()
                }
                return false
            }
            holdDropTime = 0
            if hasExcessiveMovement(holdFound) { reset(); return false }

            if activeCount == 2 {
                if let tapFinger = activeTouches.first(where: { $0.pathIndex != holdPathIndex }) {
                    if isRejectedTouch(tapFinger) {
                        return false
                    }
                    tapIsRight = tapFinger.normalizedVector.position.x > holdFound.normalizedVector.position.x
                    tapDownTime = timestamp
                    state = .tapDown
                }
            } else if activeCount > 2 {
                reset()
            }
            return false

        case .tapDown:
            let holdFound = activeTouches.contains(where: { $0.pathIndex == holdPathIndex })
            if !holdFound {
                if holdDropTime == 0 {
                    holdDropTime = timestamp
                } else if timestamp - holdDropTime > holdGracePeriod {
                    reset()
                }
                return false
            }
            holdDropTime = 0

            if activeCount == 2 {
                if timestamp - tapDownTime > maxTapDuration {
                    reset()
                }
                return false
            }

            if activeCount == 1 {
                var didFire = false
                if tapIsRight {
                    if GestureConfig.shared.isEnabled("ofhRightTap") {
                        KeySynthesizer.fireAction(gestureId: "ofhRightTap")
                        didFire = true
                    }
                } else {
                    if GestureConfig.shared.isEnabled("ofhLeftTap") {
                        KeySynthesizer.fireAction(gestureId: "ofhLeftTap")
                        didFire = true
                    }
                }
                if let heldFinger = activeTouches.first(where: { $0.pathIndex == holdPathIndex }) {
                    holdInitialX = heldFinger.normalizedVector.position.x
                    holdInitialY = heldFinger.normalizedVector.position.y
                }
                state = .holdDetected
                return didFire
            }

            reset()
            return false
        }
    }

    func reset() {
        state = .idle
        tracking = false
        holdPathIndex = -1
        holdDropTime = 0
        holdStartTime = 0
        holdInitialX = 0
        holdInitialY = 0
        tapDownTime = 0
        tapIsRight = false
    }

    private func hasExcessiveMovement(_ finger: MTTouch) -> Bool {
        let dx = finger.normalizedVector.position.x - holdInitialX
        let dy = finger.normalizedVector.position.y - holdInitialY
        return dx * dx + dy * dy > moveThreshold * moveThreshold
    }
}
