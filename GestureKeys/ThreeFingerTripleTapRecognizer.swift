import Foundation

/// Recognizes three-finger triple-tap (no physical click).
///
/// All three fingers must touch and lift three times in succession.
/// When triple-tap is enabled, the double-tap recognizer defers its fire
/// to allow the third tap to be detected (managed by GestureEngine).
///
/// State machine:
/// ```
/// [Idle] → 3 active touches → [FirstTapDown]
/// [FirstTapDown] → 0 active touches → [FirstTapUp]
/// [FirstTapUp] → 3 active touches within window → [SecondTapDown]
/// [SecondTapDown] → 0 active touches → [SecondTapUp]
/// [SecondTapUp] → 3 active touches within window → [ThirdTapDown]
/// [ThirdTapDown] → 0 active touches → fire → [Idle]
/// ```
final class ThreeFingerTripleTapRecognizer {

    enum State {
        case idle
        case firstTapDown
        case firstTapUp
        case secondTapDown
        case secondTapUp
        case fired
    }

    private(set) var state: State = .idle

    private var doubleTapWindow: TimeInterval { GestureConfig.shared.effectiveDoubleTapWindow }
    private var maxTapDuration: TimeInterval { GestureConfig.shared.effectiveMaxTapDuration }
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }
    private let gracePeriod: TimeInterval = 0.080
    private let firedTimeout: TimeInterval = 2.0

    private var tapDownTime: TimeInterval = 0
    private var tapUpTime: TimeInterval = 0
    private var firedTime: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private var initialPositions: [(pathIndex: Int32, x: Float, y: Float)] = []

    var isActive: Bool { state != .idle }

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
            return handleTapDown(activeTouches, timestamp: timestamp, nextUp: .firstTapUp)

        case .firstTapUp:
            return handleTapUp(activeTouches, timestamp: timestamp, nextDown: .secondTapDown)

        case .secondTapDown:
            return handleTapDown(activeTouches, timestamp: timestamp, nextUp: .secondTapUp)

        case .secondTapUp:
            if timestamp - tapUpTime > doubleTapWindow {
                reset()
                return false
            }
            // Fire immediately on 3rd touch-down (2 clean tap cycles already completed)
            if activeCount == 3 {
                var didFire = false
                if GestureConfig.shared.isEnabled("threeFingerTripleTap") {
                    KeySynthesizer.fireAction(gestureId: "threeFingerTripleTap")
                    didFire = true
                }
                state = .fired
                firedTime = timestamp
                return didFire
            }
            return false

        case .fired:
            if activeCount == 0 || timestamp - firedTime > firedTimeout { reset() }
            return false
        }
    }

    func reset() {
        state = .idle
        initialPositions.removeAll(keepingCapacity: true)
        tapDownTime = 0
        tapUpTime = 0
        firedTime = 0
        dropTime = 0
    }

    // MARK: - Private

    private func handleTapDown(_ activeTouches: [MTTouch], timestamp: TimeInterval, nextUp: State) -> Bool {
        let activeCount = activeTouches.count
        if activeCount > 3 { reset(); return false }
        if timestamp - tapDownTime > maxTapDuration { reset(); return false }
        if activeCount == 3 {
            dropTime = 0
            if hasExcessiveMovement(activeTouches, initialPositions: initialPositions, threshold: moveThreshold) { reset() }
            return false
        }
        if activeCount == 0 {
            tapUpTime = timestamp
            dropTime = 0
            state = nextUp
            return false
        }
        // activeCount 1-2: grace period for finger ramping out
        if dropTime == 0 { dropTime = timestamp }
        else if timestamp - dropTime > gracePeriod { reset() }
        return false
    }

    private func handleTapUp(_ activeTouches: [MTTouch], timestamp: TimeInterval, nextDown: State) -> Bool {
        if timestamp - tapUpTime > doubleTapWindow {
            reset()
            return false
        }
        if activeTouches.count == 3 {
            recordPositions(activeTouches)
            tapDownTime = timestamp
            state = nextDown
        }
        return false
    }

    private func recordPositions(_ activeTouches: [MTTouch]) {
        initialPositions.removeAll(keepingCapacity: true)
        for touch in activeTouches {
            initialPositions.append((pathIndex: touch.pathIndex, x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y))
        }
    }

}
