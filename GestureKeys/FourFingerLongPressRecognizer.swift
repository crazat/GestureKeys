import Foundation

/// Recognizes four-finger long press (500ms+) → screen capture UI (Cmd+Shift+5).
///
/// Fires once when hold duration is reached; waits for all fingers to lift before resetting.
final class FourFingerLongPressRecognizer {

    enum State {
        case idle
        case fourDown
        case fired
    }

    private(set) var state: State = .idle

    private var longPressDuration: TimeInterval { GestureConfig.shared.effectiveLongPressDuration(base: 0.500) }
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }
    private let gracePeriod: TimeInterval = 0.080
    private var pressStartTime: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]

    var isActive: Bool { state != .idle }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            if activeCount == 4 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                pressStartTime = timestamp
                state = .fourDown
            }
            return false

        case .fourDown:
            if activeCount < 4 {
                if dropTime == 0 { dropTime = timestamp }
                else if timestamp - dropTime > gracePeriod { state = .idle }
                return false
            }
            if activeCount > 4 {
                state = .idle
                return false
            }
            dropTime = 0
            if hasExcessiveMovement(activeTouches) { state = .idle; return false }
            if timestamp - pressStartTime >= longPressDuration {
                var didFire = false
                if GestureConfig.shared.isEnabled("fourFingerLongPress") {
                    KeySynthesizer.fireAction(gestureId: "fourFingerLongPress")
                    didFire = true
                }
                state = .fired
                return didFire
            }
            return false

        case .fired:
            if activeCount == 0 { state = .idle }
            return false
        }
    }

    func reset() {
        state = .idle
        initialPositions.removeAll(keepingCapacity: true)
        dropTime = 0
        pressStartTime = 0
    }

    private func hasExcessiveMovement(_ activeTouches: [MTTouch]) -> Bool {
        for touch in activeTouches {
            if let initial = initialPositions[touch.pathIndex] {
                let dx = touch.normalizedVector.position.x - initial.x
                let dy = touch.normalizedVector.position.y - initial.y
                if dx * dx + dy * dy > moveThreshold * moveThreshold { return true }
            }
        }
        return false
    }
}
