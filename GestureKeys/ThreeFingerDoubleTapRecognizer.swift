import Foundation

/// Recognizes three-finger double-tap (no physical click) → Cmd+V (paste).
///
/// All three fingers must touch and lift together, then touch and lift again.
/// Distinguished from three-finger click (requires physical click) and
/// TWH (requires 2 fingers held continuously).
///
/// State machine:
/// ```
/// [Idle] → 3 active touches → [FirstTapDown]
/// [FirstTapDown] → 0 active touches → [FirstTapUp]
/// [FirstTapUp] → 3 active touches within 400ms → [SecondTapDown]
/// [SecondTapDown] → 0 active touches → fire Cmd+R → [Idle]
/// ```
final class ThreeFingerDoubleTapRecognizer {

    enum State {
        case idle
        case firstTapDown
        case firstTapUp
        case secondTapDown
    }

    private(set) var state: State = .idle

    /// Maximum time between first tap up and second tap down
    private var doubleTapWindow: TimeInterval { GestureConfig.shared.effectiveDoubleTapWindow }

    /// Maximum time fingers can be held down and still count as a "tap"
    private var maxTapDuration: TimeInterval { GestureConfig.shared.effectiveMaxTapDuration }

    /// Maximum normalized movement before we consider it a swipe
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }

    /// Grace period for brief finger lift during tap-down states
    private let gracePeriod: TimeInterval = 0.080

    /// Timestamp when fingers first landed
    private var tapDownTime: TimeInterval = 0

    /// Timestamp when first tap lifted
    private var firstTapUpTime: TimeInterval = 0

    /// Timestamp when finger count dropped below target
    private var dropTime: TimeInterval = 0

    /// Initial positions when three fingers landed
    private var initialPositions: [(pathIndex: Int32, x: Float, y: Float)] = []

    /// When true, the recognizer will not fire on second tap lift (set by GestureEngine
    /// when triple-tap is enabled and tracking, to allow deferred double-tap execution).
    var suppressFire = false

    /// Set to true when fire was suppressed; GestureEngine reads and clears this.
    var didSuppressFire = false

    var isActive: Bool {
        state != .idle
    }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            if activeCount == 3 {
                recordPositions(activeTouches)
                tapDownTime = timestamp
                state = .firstTapDown
            }
            return false

        case .firstTapDown:
            if activeCount > 3 { reset(); return false }
            if timestamp - tapDownTime > maxTapDuration { reset(); return false }
            if activeCount == 3 {
                dropTime = 0
                if hasExcessiveMovement(activeTouches) { reset() }
                return false
            }
            if activeCount == 0 {
                firstTapUpTime = timestamp
                dropTime = 0
                state = .firstTapUp
                return false
            }
            // activeCount 1-2: grace period for finger ramping out
            if dropTime == 0 { dropTime = timestamp }
            else if timestamp - dropTime > gracePeriod { reset() }
            return false

        case .firstTapUp:
            if timestamp - firstTapUpTime > doubleTapWindow {
                reset()
                return false
            }
            if activeCount == 3 {
                recordPositions(activeTouches)
                tapDownTime = timestamp
                state = .secondTapDown
            }
            return false

        case .secondTapDown:
            if activeCount > 3 { reset(); return false }
            if timestamp - tapDownTime > maxTapDuration { reset(); return false }
            if activeCount == 3 {
                dropTime = 0
                if hasExcessiveMovement(activeTouches) { reset() }
                return false
            }
            if activeCount == 0 {
                if suppressFire {
                    didSuppressFire = true
                    reset()
                    return false
                }
                var didFire = false
                if GestureConfig.shared.isEnabled("threeFingerDoubleTap") {
                    KeySynthesizer.fireAction(gestureId: "threeFingerDoubleTap")
                    didFire = true
                }
                reset()
                return didFire
            }
            // activeCount 1-2: grace period for finger ramping out
            if dropTime == 0 { dropTime = timestamp }
            else if timestamp - dropTime > gracePeriod { reset() }
            return false
        }
    }

    func reset() {
        state = .idle
        initialPositions.removeAll(keepingCapacity: true)
        tapDownTime = 0
        firstTapUpTime = 0
        dropTime = 0
    }

    // MARK: - Private

    private func recordPositions(_ activeTouches: [MTTouch]) {
        initialPositions.removeAll(keepingCapacity: true)
        for touch in activeTouches {
            initialPositions.append((pathIndex: touch.pathIndex, x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y))
        }
    }

    private func hasExcessiveMovement(_ activeTouches: [MTTouch]) -> Bool {
        for touch in activeTouches {
            if let initial = initialPositions.first(where: { $0.pathIndex == touch.pathIndex }) {
                let dx = touch.normalizedVector.position.x - initial.x
                let dy = touch.normalizedVector.position.y - initial.y
                if dx * dx + dy * dy > moveThreshold * moveThreshold {
                    return true
                }
            }
        }
        return false
    }
}
