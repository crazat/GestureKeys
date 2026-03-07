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

    /// Maximum time between first tap up and second tap down
    private var doubleTapWindow: TimeInterval { GestureConfig.shared.effectiveDoubleTapWindow }

    /// Shared hold detection logic
    private var hold = TwoFingerHoldDetector()

    /// Timestamp when first tap lifted
    private var firstTapUpTime: TimeInterval = 0

    /// Whether the tapping finger is to the right of the held fingers
    private var tapIsRight = false

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            if hold.processIdle(activeTouches: activeTouches, timestamp: timestamp,
                                holdStabilityDuration: GestureConfig.shared.effectiveHoldStability) {
                state = .holdDetected
            }
            return false

        case .holdDetected:
            if activeCount < 2 {
                if !hold.handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            hold.dropTime = 0
            if hold.isTimedOut(timestamp: timestamp) {
                reset()
                return false
            }
            if activeCount == 2 {
                hold.updateHoldPosition(activeTouches)
                hold.holdConfirmed = true
            }
            if activeCount >= 3 && hold.holdConfirmed {
                tapIsRight = detectTapSide(activeTouches: activeTouches)
                state = .firstTapDown
            }
            return false

        case .firstTapDown:
            if activeCount < 2 {
                if !hold.handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            hold.dropTime = 0
            if activeCount == 2 {
                firstTapUpTime = timestamp
                state = .firstTapUp
            }
            return false

        case .firstTapUp:
            if activeCount < 2 {
                if !hold.handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            hold.dropTime = 0
            if timestamp - firstTapUpTime > doubleTapWindow {
                state = .holdDetected
                hold.holdDetectedTime = timestamp
                return false
            }
            if activeCount >= 3 {
                state = .secondTapDown
            }
            return false

        case .secondTapDown:
            if activeCount < 2 {
                if !hold.handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            hold.dropTime = 0
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
                state = .holdDetected
                hold.holdDetectedTime = timestamp
                firstTapUpTime = 0
                hold.dropTime = 0
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
        hold.reset()
        firstTapUpTime = 0
        tapIsRight = false
    }

    // MARK: - Private

    /// Determines if the tapping finger is to the right of the held fingers.
    /// Skips held fingers and finds the non-held finger furthest from the hold center.
    private func detectTapSide(activeTouches: [MTTouch]) -> Bool {
        var maxDist: Float = 0
        var tapX: Float = hold.holdAverageX
        for touch in activeTouches {
            guard !hold.holdPathIndices.contains(touch.pathIndex) else { continue }
            let x = touch.normalizedVector.position.x
            let dist = abs(x - hold.holdAverageX)
            if dist > maxDist {
                maxDist = dist
                tapX = x
            }
        }
        return tapX > hold.holdAverageX
    }
}
