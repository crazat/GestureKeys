import Foundation

/// Recognizes three-finger long press (500ms+) → Cmd+Z (undo).
///
/// Fires once when the hold duration is reached while fingers are still down.
/// Enters cooldown until all fingers lift to prevent repeated firing.
///
/// State machine:
/// ```
/// [Idle] → 3 active touches → [ThreeDown] (record time + positions)
/// [ThreeDown] → held 500ms without movement → fire Cmd+Z → [Fired]
/// [ThreeDown] → movement or count != 3 → [Idle]
/// [Fired] → all fingers lift → [Idle]
/// ```
final class ThreeFingerLongPressRecognizer {

    enum State {
        case idle
        case threeDown
        case fired
    }

    private(set) var state: State = .idle

    private var longPressDuration: TimeInterval { GestureConfig.shared.effectiveLongPressDuration(base: 0.500) }
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }
    private let gracePeriod: TimeInterval = 0.080
    private var pressStartTime: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]

    var isActive: Bool {
        state != .idle
    }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            if activeCount == 3 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                pressStartTime = timestamp
                state = .threeDown
            }
            return false

        case .threeDown:
            if activeCount < 3 {
                if dropTime == 0 { dropTime = timestamp }
                else if timestamp - dropTime > gracePeriod { state = .idle }
                return false
            }
            if activeCount > 3 {
                state = .idle
                return false
            }
            dropTime = 0
            if hasExcessiveMovement(activeTouches) {
                state = .idle
                return false
            }
            if timestamp - pressStartTime >= longPressDuration {
                var didFire = false
                if GestureConfig.shared.isEnabled("threeFingerLongPress") {
                    KeySynthesizer.fireAction(gestureId: "threeFingerLongPress")
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
        pressStartTime = 0
        dropTime = 0
    }

    // MARK: - Private

    private func hasExcessiveMovement(_ activeTouches: [MTTouch]) -> Bool {
        for touch in activeTouches {
            if let initial = initialPositions[touch.pathIndex] {
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
