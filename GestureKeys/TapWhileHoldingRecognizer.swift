import Foundation

/// Recognizes two-finger hold + third finger double-tap.
///
/// Tap position determines the action:
/// - Tap to the LEFT of held fingers → Cmd+W (close tab)
/// - Tap to the RIGHT of held fingers → Cmd+T (new tab)
///
/// Distinguished from three-finger click by not requiring physical click.
///
/// State machine:
/// ```
/// [Idle] → 2+ active touches stable 100ms → [HoldDetected]
/// [HoldDetected] → active count rises to 3+ → [FirstTapDown]
/// [FirstTapDown] → active count drops to 2 → [FirstTapUp]
/// [FirstTapUp] → active count rises to 3+ within 400ms → [SecondTapDown]
/// [SecondTapDown] → active count drops to 2 → fire action → [Idle]
/// ```
final class TapWhileHoldingRecognizer {

    enum State {
        case idle
        case holdDetected
        case firstTapDown
        case firstTapUp
        case secondTapDown
    }

    private(set) var state: State = .idle

    /// How long 2 fingers must be stable before hold is detected
    private var holdStabilityDuration: TimeInterval { GestureConfig.shared.effectiveHoldStability }

    /// Maximum time between first tap up and second tap down
    private var doubleTapWindow: TimeInterval { GestureConfig.shared.effectiveDoubleTapWindow }

    /// Grace period: how long active count can drop below 2 before resetting
    private let gracePeriod: TimeInterval = 0.080

    /// Safety timeout: reset holdDetected if no tap occurs within this time
    private let holdTimeout: TimeInterval = 10.0

    /// Timestamp when 2 fingers first appeared
    private var holdStartTime: TimeInterval = 0

    /// Timestamp when holdDetected state was entered (for timeout)
    private var holdDetectedTime: TimeInterval = 0

    /// Timestamp when active count last dropped below 2
    private var dropTime: TimeInterval = 0

    /// Whether we've been tracking 2+ touches
    private var tracking = false

    /// Timestamp when first tap lifted
    private var firstTapUpTime: TimeInterval = 0

    /// Average x position of the held fingers when hold was detected
    private var holdAverageX: Float = 0

    /// Whether the tapping finger is to the right of the held fingers
    private var tapIsRight = false

    /// True once we've confirmed exactly 2 fingers in holdDetected (prevents
    /// false activation when 3+ fingers are placed simultaneously)
    private var holdConfirmed = false

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            handleIdle(activeTouches: activeTouches, timestamp: timestamp)
            return false

        case .holdDetected:
            if activeCount < 2 {
                if !handleGrace(timestamp: timestamp) {
                        reset()
                }
                return false
            }
            dropTime = 0
            if holdDetectedTime > 0 && timestamp - holdDetectedTime > holdTimeout {
                reset()
                return false
            }
            // Update hold position while waiting for tap
            if activeCount == 2 {
                holdAverageX = activeTouches.reduce(Float(0)) { $0 + $1.normalizedVector.position.x } / 2.0
                holdConfirmed = true
            }
            if activeCount >= 3 && holdConfirmed {
                tapIsRight = detectTapSide(activeTouches: activeTouches)
                state = .firstTapDown
            }
            return false

        case .firstTapDown:
            if activeCount < 2 {
                if !handleGrace(timestamp: timestamp) {
                    reset()
                }
                return false
            }
            dropTime = 0
            if activeCount == 2 {
                firstTapUpTime = timestamp
                state = .firstTapUp
            }
            return false

        case .firstTapUp:
            if activeCount < 2 {
                if !handleGrace(timestamp: timestamp) {
                    reset()
                }
                return false
            }
            dropTime = 0
            if timestamp - firstTapUpTime > doubleTapWindow {
                state = .holdDetected
                holdDetectedTime = timestamp
                return false
            }
            if activeCount >= 3 {
                state = .secondTapDown
            }
            return false

        case .secondTapDown:
            if activeCount < 2 {
                if !handleGrace(timestamp: timestamp) {
                    reset()
                }
                return false
            }
            dropTime = 0
            if activeCount == 2 {
                var didFire = false
                if tapIsRight {
                    if GestureConfig.shared.isEnabled("twhRightDoubleTap") {
                        KeySynthesizer.fireAction(gestureId: "twhRightDoubleTap")
                        didFire = true
                    }
                } else {
                    if GestureConfig.shared.isEnabled("twhLeftDoubleTap") {
                        KeySynthesizer.fireAction(gestureId: "twhLeftDoubleTap")
                        didFire = true
                    }
                }
                // Preserve hold state for consecutive gestures (don't reset to idle)
                state = .holdDetected
                holdDetectedTime = timestamp
                firstTapUpTime = 0
                dropTime = 0
                tapIsRight = false
                return didFire
            }
            return false
        }
    }

    var isActive: Bool {
        switch state {
        case .idle, .holdDetected: return false
        case .firstTapDown, .firstTapUp, .secondTapDown: return true
        }
    }

    func reset() {
        state = .idle
        tracking = false
        holdStartTime = 0
        holdDetectedTime = 0
        firstTapUpTime = 0
        dropTime = 0
        holdAverageX = 0
        tapIsRight = false
        holdConfirmed = false
    }

    // MARK: - Private

    private func handleIdle(activeTouches: [MTTouch], timestamp: TimeInterval) {
        // Filter extreme edge/palm touches for hold detection
        // (wider typing-zone filter is handled by GestureEngine's twoFingerSuppressed)
        var qualityCount = 0
        for touch in activeTouches where !touch.isEdgeTouch && !touch.isPalmSized { qualityCount += 1 }
        if qualityCount >= 2 {
            if tracking {
                if timestamp - holdStartTime >= holdStabilityDuration {
                    state = .holdDetected
                    holdDetectedTime = timestamp
                }
            } else {
                tracking = true
                holdStartTime = timestamp
            }
        } else {
            // Allow brief dips during idle tracking too
            if tracking {
                if dropTime == 0 {
                    dropTime = timestamp
                } else if timestamp - dropTime > gracePeriod {
                    tracking = false
                    dropTime = 0
                }
            }
        }
    }

    /// Determines if the tapping finger is to the right of the held fingers.
    /// Finds the finger furthest from the hold average x position.
    private func detectTapSide(activeTouches: [MTTouch]) -> Bool {
        var maxDist: Float = 0
        var tapX: Float = holdAverageX
        for touch in activeTouches {
            let x = touch.normalizedVector.position.x
            let dist = abs(x - holdAverageX)
            if dist > maxDist {
                maxDist = dist
                tapX = x
            }
        }
        return tapX > holdAverageX
    }

    /// Returns true if we're still within the grace period (don't reset yet)
    private func handleGrace(timestamp: TimeInterval) -> Bool {
        if dropTime == 0 {
            dropTime = timestamp
            return true
        }
        return timestamp - dropTime <= gracePeriod
    }
}
