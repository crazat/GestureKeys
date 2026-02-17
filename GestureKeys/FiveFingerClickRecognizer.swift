import Foundation

/// Recognizes five-finger physical click → app quit (⌘Q).
///
/// State machine:
/// ```
/// [Idle] → 5 active touches → [FiveDown]
/// [FiveDown] + physical click → fire → [Cooldown]
/// [FiveDown] + 6+ fingers → [Idle]
/// [FiveDown] + fingers < 5 → [Idle]
/// [Cooldown] (200ms) → [Idle]
/// ```
final class FiveFingerClickRecognizer {

    enum State {
        case idle
        case fiveDown
        case cooldown
    }

    private(set) var state: State = .idle

    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.05) }
    private let cooldownDuration: TimeInterval = 0.2
    private let gracePeriod: TimeInterval = 0.200

    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]
    private var cooldownStart: TimeInterval = 0
    private var dropTime: TimeInterval = 0

    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) {
        switch state {
        case .idle:
            if activeTouches.count == 5 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                state = .fiveDown
            }

        case .fiveDown:
            if activeTouches.count > 5 {
                state = .idle
                return
            }
            if activeTouches.count < 5 {
                if dropTime == 0 { dropTime = timestamp }
                else if timestamp - dropTime > gracePeriod { state = .idle }
                return
            }
            dropTime = 0
            if hasExcessiveMovement(activeTouches) {
                state = .idle
            }

        case .cooldown:
            if timestamp - cooldownStart >= cooldownDuration {
                state = .idle
            }
        }
    }

    /// Called by GestureEngine when a physical click is detected.
    /// Returns true if the click should be suppressed.
    func handlePhysicalClick() -> Bool {
        guard state == .fiveDown else { return false }
        guard GestureConfig.shared.isEnabled("fiveFingerClick") else {
            state = .idle
            return false
        }

        KeySynthesizer.fireAction(gestureId: "fiveFingerClick")
        state = .cooldown
        cooldownStart = ProcessInfo.processInfo.systemUptime
        return true
    }

    func reset() {
        state = .idle
        initialPositions.removeAll(keepingCapacity: true)
        dropTime = 0
        cooldownStart = 0
    }

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
