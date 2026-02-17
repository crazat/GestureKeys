import Foundation

/// Recognizes four-finger double-tap (no physical click) → screenshot (Cmd+Shift+4).
///
/// All four fingers must touch and lift together, then touch and lift again.
final class FourFingerDoubleTapRecognizer {

    enum State {
        case idle
        case firstTapDown
        case firstTapUp
        case secondTapDown
    }

    private(set) var state: State = .idle

    private var doubleTapWindow: TimeInterval { GestureConfig.shared.effectiveDoubleTapWindow }
    private var maxTapDuration: TimeInterval { GestureConfig.shared.effectiveMaxTapDuration }
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }
    private let gracePeriod: TimeInterval = 0.080

    private var tapDownTime: TimeInterval = 0
    private var firstTapUpTime: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private var initialPositions: [(pathIndex: Int32, x: Float, y: Float)] = []

    var isActive: Bool { state != .idle }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            if activeCount == 4 {
                recordPositions(activeTouches)
                tapDownTime = timestamp
                state = .firstTapDown
            }
            return false

        case .firstTapDown:
            if activeCount > 4 { reset(); return false }
            if timestamp - tapDownTime > maxTapDuration { reset(); return false }
            if activeCount == 4 {
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
            if dropTime == 0 { dropTime = timestamp }
            else if timestamp - dropTime > gracePeriod { reset() }
            return false

        case .firstTapUp:
            if timestamp - firstTapUpTime > doubleTapWindow { reset(); return false }
            if activeCount == 4 {
                recordPositions(activeTouches)
                tapDownTime = timestamp
                state = .secondTapDown
            }
            return false

        case .secondTapDown:
            if activeCount > 4 { reset(); return false }
            if timestamp - tapDownTime > maxTapDuration { reset(); return false }
            if activeCount == 4 {
                dropTime = 0
                if hasExcessiveMovement(activeTouches) { reset() }
                return false
            }
            if activeCount == 0 {
                var didFire = false
                if GestureConfig.shared.isEnabled("fourFingerDoubleTap") {
                    KeySynthesizer.fireAction(gestureId: "fourFingerDoubleTap")
                    didFire = true
                }
                reset()
                return didFire
            }
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
                if dx * dx + dy * dy > moveThreshold * moveThreshold { return true }
            }
        }
        return false
    }
}
