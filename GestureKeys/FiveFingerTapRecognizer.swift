import Foundation

/// Recognizes five-finger single tap → lock screen (Ctrl+Cmd+Q).
///
/// All five fingers must touch briefly and lift together.
final class FiveFingerTapRecognizer {

    enum State {
        case idle
        case fiveDown
    }

    private(set) var state: State = .idle

    private var maxTapDuration: TimeInterval { GestureConfig.shared.effectiveMaxTapDuration }
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }
    private let gracePeriod: TimeInterval = 0.080

    private var tapDownTime: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private var initialPositions: [(pathIndex: Int32, x: Float, y: Float)] = []

    var isActive: Bool { state != .idle }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            if activeCount == 5 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions.append((pathIndex: touch.pathIndex, x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y))
                }
                tapDownTime = timestamp
                state = .fiveDown
            }
            return false

        case .fiveDown:
            if timestamp - tapDownTime > maxTapDuration { reset(); return false }
            if activeCount > 5 { reset(); return false }
            if activeCount == 5 {
                dropTime = 0
                if hasExcessiveMovement(activeTouches) { reset() }
                return false
            }
            if activeCount == 0 {
                var didFire = false
                if GestureConfig.shared.isEnabled("fiveFingerTap") {
                    KeySynthesizer.fireAction(gestureId: "fiveFingerTap")
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
        dropTime = 0
        tapDownTime = 0
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
