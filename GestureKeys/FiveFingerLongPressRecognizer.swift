import Foundation

/// Recognizes five-finger long press (500ms+) → Force Quit dialog (⌥⌘Esc).
///
/// Fires once when hold duration is reached; waits for all fingers to lift before resetting.
final class FiveFingerLongPressRecognizer {

    enum State {
        case idle
        case fiveDown
        case fired
    }

    private(set) var state: State = .idle

    /// True when fingers lifted after a sleepDisplay fire; consumed by GestureEngine.
    private(set) var liftedAfterFire = false

    private var longPressDuration: TimeInterval { GestureConfig.shared.effectiveLongPressDuration(base: 0.500) }
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.03) }
    private let gracePeriod: TimeInterval = 0.080
    private var pressStartTime: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]
    private var deferredSleep = false

    var isActive: Bool { state != .idle }

    /// Atomically consumes the lift event. Returns true once after fingers lift from a deferred sleep.
    func consumeLiftEvent() -> Bool {
        guard liftedAfterFire else { return false }
        liftedAfterFire = false
        return true
    }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            if activeCount == 5 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                pressStartTime = timestamp
                state = .fiveDown
            }
            return false

        case .fiveDown:
            if activeCount < 5 {
                if dropTime == 0 { dropTime = timestamp }
                else if timestamp - dropTime > gracePeriod { state = .idle }
                return false
            }
            if activeCount > 5 {
                state = .idle
                return false
            }
            dropTime = 0
            if hasExcessiveMovement(activeTouches) { state = .idle; return false }
            if timestamp - pressStartTime >= longPressDuration {
                var didFire = false
                if GestureConfig.shared.isEnabled("fiveFingerLongPress") {
                    if GestureConfig.shared.actionFor("fiveFingerLongPress") == .sleepDisplay {
                        // Defer sleep to finger lift; fire HUD/haptic only
                        KeySynthesizer.fireAction(gestureId: "fiveFingerLongPress", action: {})
                        deferredSleep = true
                    } else {
                        KeySynthesizer.fireAction(gestureId: "fiveFingerLongPress")
                    }
                    didFire = true
                }
                state = .fired
                return didFire
            }
            return false

        case .fired:
            if activeCount == 0 {
                if deferredSleep { liftedAfterFire = true; deferredSleep = false }
                state = .idle
            }
            return false
        }
    }

    func reset() {
        state = .idle
        liftedAfterFire = false
        deferredSleep = false
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
