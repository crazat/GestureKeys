import Foundation

/// Recognizes two-finger double-tap → copy (⌘C).
///
/// Each tap: 2 fingers touch briefly and lift together.
/// Double-tap fires copy immediately on second lift.
///
/// State machine:
/// ```
/// [Idle] → 2 active → [FirstDown]
/// [FirstDown] → 0 active (within 250ms) → [FirstUp]
/// [FirstUp] → 2 active (within 350ms) → [SecondDown]
/// [SecondDown] → 0 active → fire copy → [Idle]
/// ```
final class TwoFingerTapRecognizer {

    enum State {
        case idle
        case firstDown
        case firstUp
        case secondDown
    }

    private(set) var state: State = .idle

    private var maxTapDuration: TimeInterval { GestureConfig.shared.effectiveMaxTapDuration }
    private var multiTapWindow: TimeInterval { GestureConfig.shared.effectiveMultiTapWindow }
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }
    private let gracePeriod: TimeInterval = 0.080

    private var tapDownTime: TimeInterval = 0
    private var tapUpTime: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private var initialPositions: [(pathIndex: Int32, x: Float, y: Float)] = []

    var isActive: Bool { state != .idle }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            let qualityTouches = activeTouches.filter { !$0.isTypingEdge && !$0.isPalmSized }
            if qualityTouches.count == 2 && activeCount == 2 {
                recordPositions(qualityTouches)
                tapDownTime = timestamp
                state = .firstDown
            }
            return false

        case .firstDown:
            if timestamp - tapDownTime > maxTapDuration { reset(); return false }
            if activeCount > 2 { reset(); return false }
            if activeCount == 2 {
                dropTime = 0
                if hasExcessiveMovement(activeTouches) { reset() }
                return false
            }
            if activeCount == 0 {
                tapUpTime = timestamp
                dropTime = 0
                state = .firstUp
                return false
            }
            if dropTime == 0 { dropTime = timestamp }
            else if timestamp - dropTime > gracePeriod { reset() }
            return false

        case .firstUp:
            if timestamp - tapUpTime > multiTapWindow { reset(); return false }
            if activeCount == 2 {
                recordPositions(activeTouches)
                tapDownTime = timestamp
                state = .secondDown
            }
            return false

        case .secondDown:
            if timestamp - tapDownTime > maxTapDuration { reset(); return false }
            if activeCount > 2 { reset(); return false }
            if activeCount == 2 {
                dropTime = 0
                if hasExcessiveMovement(activeTouches) { reset() }
                return false
            }
            if activeCount == 0 {
                var didFire = false
                if GestureConfig.shared.isEnabled("twoFingerDoubleTap") {
                    KeySynthesizer.fireAction(gestureId: "twoFingerDoubleTap")
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
        tapUpTime = 0
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
