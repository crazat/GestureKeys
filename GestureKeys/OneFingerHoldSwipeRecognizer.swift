import Foundation

/// Recognizes one-finger hold + vertical swipe with another finger.
///
/// LEFT side:
/// - Swipe up → volume up
/// - Swipe down → volume down
///
/// RIGHT side:
/// - Swipe up → brightness up
/// - Swipe down → brightness down
///
/// State machine:
/// ```
/// [Idle] → 1 finger stable 200ms → [HoldDetected]
/// [HoldDetected] → 2nd finger appears → [Tracking]
/// [Tracking] → vertical displacement ≥ threshold → fire → [Fired]
/// [Tracking] → 2nd finger lifts (no swipe) → [HoldDetected]
/// [Fired] → 2nd finger lifts → [HoldDetected]
/// ```
final class OneFingerHoldSwipeRecognizer {

    enum State {
        case idle
        case holdDetected
        case tracking
        case fired
    }

    private(set) var state: State = .idle

    private let holdDuration: TimeInterval = 0.150
    private var holdMoveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }
    private var swipeThreshold: Float { GestureConfig.shared.effectiveSwipeThreshold(base: 0.06) }
    private let maxDuration: TimeInterval = 0.800
    private let minSwipeDuration: TimeInterval = 0.060

    private let holdGracePeriod: TimeInterval = 0.080

    // Hold finger
    private var trackingHold = false
    private var holdStartTime: TimeInterval = 0
    private var holdPathIndex: Int32 = -1
    private var holdInitialX: Float = 0
    private var holdInitialY: Float = 0
    private var holdDropTime: TimeInterval = 0

    // Swipe finger
    private var swipeStartTime: TimeInterval = 0
    private var swipePathIndex: Int32 = -1
    private var swipeInitialX: Float = 0
    private var swipeInitialY: Float = 0
    private var swipeIsRight = false

    /// How long ago the last external keystroke occurred (set by GestureEngine).
    var lastExternalKeyTime: TimeInterval = 0

    var isActive: Bool { state == .tracking || state == .fired }

    /// Dynamic touch rejection: strict zone during typing, permissive otherwise.
    private func isRejectedTouch(_ touch: MTTouch) -> Bool {
        if touch.isPalmSized { return true }
        let timeSinceTyping = ProcessInfo.processInfo.systemUptime - lastExternalKeyTime
        if timeSinceTyping < 2.0 {
            return touch.isTypingEdge
        } else {
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
                // Dynamic zone: strict after typing, permissive otherwise
                if isRejectedTouch(finger) {
                    trackingHold = false
                    return false
                }
                if !trackingHold || finger.pathIndex != holdPathIndex {
                    trackingHold = true
                    holdStartTime = timestamp
                    holdPathIndex = finger.pathIndex
                    holdInitialX = finger.normalizedVector.position.x
                    holdInitialY = finger.normalizedVector.position.y
                } else if holdFingerMoved(finger) {
                    holdStartTime = timestamp
                    holdInitialX = finger.normalizedVector.position.x
                    holdInitialY = finger.normalizedVector.position.y
                } else if timestamp - holdStartTime >= holdDuration {
                    state = .holdDetected
                }
            } else {
                trackingHold = false
            }

        case .holdDetected:
            guard let heldFinger = activeTouches.first(where: { $0.pathIndex == holdPathIndex }) else {
                // Grace period: allow brief lift during rapid use
                if holdDropTime == 0 {
                    holdDropTime = timestamp
                } else if timestamp - holdDropTime > holdGracePeriod {
                    reset()
                }
                return false
            }
            holdDropTime = 0
            if holdFingerMoved(heldFinger) { reset(); return false }

            if activeCount == 2 {
                if let swipeFinger = activeTouches.first(where: { $0.pathIndex != holdPathIndex }) {
                    // Dynamic zone: strict after typing, permissive otherwise
                    if isRejectedTouch(swipeFinger) {
                        return false
                    }
                    swipeIsRight = swipeFinger.normalizedVector.position.x > heldFinger.normalizedVector.position.x
                    swipePathIndex = swipeFinger.pathIndex
                    swipeInitialX = swipeFinger.normalizedVector.position.x
                    swipeInitialY = swipeFinger.normalizedVector.position.y
                    swipeStartTime = timestamp
                    state = .tracking
                }
            } else if activeCount > 2 {
                reset()
            }

        case .tracking:
            guard activeTouches.contains(where: { $0.pathIndex == holdPathIndex }) else {
                reset(); return false
            }

            if activeCount == 1 {
                // Swipe finger lifted without enough movement (was a tap)
                state = .holdDetected
                return false
            }

            if activeCount != 2 { reset(); return false }
            if timestamp - swipeStartTime > maxDuration { state = .holdDetected; return false }

            guard let swipeFinger = activeTouches.first(where: { $0.pathIndex == swipePathIndex }) else {
                state = .holdDetected; return false
            }

            let dx = swipeFinger.normalizedVector.position.x - swipeInitialX
            let dy = swipeFinger.normalizedVector.position.y - swipeInitialY

            // Require primarily vertical movement (2x ratio) and minimum duration
            // to avoid noise from brief palm contact
            if abs(dy) >= swipeThreshold && abs(dy) > abs(dx) * 2.0
                && timestamp - swipeStartTime >= minSwipeDuration {
                let config = GestureConfig.shared
                var didFire = false
                if !swipeIsRight {
                    if dy > 0 {
                        if config.isEnabled("ofhLeftSwipeUp") {
                            KeySynthesizer.fireAction(gestureId: "ofhLeftSwipeUp")
                            didFire = true
                        }
                    } else {
                        if config.isEnabled("ofhLeftSwipeDown") {
                            KeySynthesizer.fireAction(gestureId: "ofhLeftSwipeDown")
                            didFire = true
                        }
                    }
                } else {
                    if dy > 0 {
                        if config.isEnabled("ofhRightSwipeUp") {
                            KeySynthesizer.fireAction(gestureId: "ofhRightSwipeUp")
                            didFire = true
                        }
                    } else {
                        if config.isEnabled("ofhRightSwipeDown") {
                            KeySynthesizer.fireAction(gestureId: "ofhRightSwipeDown")
                            didFire = true
                        }
                    }
                }
                if didFire {
                    state = .fired
                    return true
                } else {
                    // Gesture disabled — ignore and return to hold
                    state = .holdDetected
                    return false
                }
            }

        case .fired:
            guard activeTouches.contains(where: { $0.pathIndex == holdPathIndex }) else {
                reset(); return false
            }
            if activeCount <= 1 {
                // Update hold reference to current position (prevents cumulative drift)
                if let heldFinger = activeTouches.first(where: { $0.pathIndex == holdPathIndex }) {
                    holdInitialX = heldFinger.normalizedVector.position.x
                    holdInitialY = heldFinger.normalizedVector.position.y
                }
                state = .holdDetected
            }
        }

        return false
    }

    func reset() {
        state = .idle
        trackingHold = false
        holdPathIndex = -1
        holdDropTime = 0
        holdStartTime = 0
        holdInitialX = 0
        holdInitialY = 0
        swipeStartTime = 0
        swipePathIndex = -1
        swipeInitialX = 0
        swipeInitialY = 0
        swipeIsRight = false
    }

    private func holdFingerMoved(_ finger: MTTouch) -> Bool {
        let dx = finger.normalizedVector.position.x - holdInitialX
        let dy = finger.normalizedVector.position.y - holdInitialY
        return dx * dx + dy * dy > holdMoveThreshold * holdMoveThreshold
    }
}
