import Foundation

/// Recognizes two-finger hold + third-finger long press.
///
/// - Left side → Redo (⇧⌘Z)
/// - Right side → Save (⌘S)
///
/// Distinguished from TWH (double-tap) by hold duration:
/// - Tap < 300ms → TWH handles it
/// - Hold >= 300ms → this recognizer fires
///
/// State machine:
/// ```
/// [Idle] → 2+ active stable 100ms → [HoldDetected]
/// [HoldDetected] → 3+ active, new finger LEFT, holdConfirmed → [Pressing]
/// [Pressing] → held 300ms+ → fire Redo → [Fired]
/// [Pressing] → finger lifts before 300ms → [HoldDetected]
/// [Fired] → finger lifts → [HoldDetected]
/// ```
final class LongPressWhileHoldingRecognizer {

    enum State {
        case idle
        case holdDetected
        case pressing
        case fired
    }

    private(set) var state: State = .idle

    private var longPressDuration: TimeInterval { GestureConfig.shared.effectiveLongPressDuration(base: 0.400) }
    private let firedTimeout: TimeInterval = 5.0

    /// Shared hold detection logic
    private var hold = TwoFingerHoldDetector()

    // Press tracking
    private var pressStartTime: TimeInterval = 0
    private var pressIsLeft = true
    private var firedTime: TimeInterval = 0

    var isActive: Bool { state == .pressing || state == .fired }

    /// Returns true if the long press fired this frame.
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

            if activeCount >= 3 && hold.holdConfirmed && !hold.holdPathIndices.isEmpty {
                if let newFinger = activeTouches.first(where: { !self.hold.holdPathIndices.contains($0.pathIndex) }) {
                    let newX = newFinger.normalizedVector.position.x
                    pressIsLeft = newX < hold.holdAverageX
                    pressStartTime = timestamp
                    state = .pressing
                }
            }
            return false

        case .pressing:
            if activeCount < 2 {
                if !hold.handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            // 4+ fingers → likely a different gesture (4FC, 5FT, etc.)
            if activeCount > 3 { reset(); return false }
            hold.dropTime = 0

            if activeCount == 2 {
                state = .holdDetected
                return false
            }

            if activeCount >= 3 && timestamp - pressStartTime >= longPressDuration {
                let gestureId = pressIsLeft ? "twhLeftLongPress" : "twhRightLongPress"
                if GestureConfig.shared.isEnabled(gestureId) {
                    KeySynthesizer.fireAction(gestureId: gestureId)
                }
                state = .fired
                firedTime = timestamp
                return true
            }
            return false

        case .fired:
            if activeCount < 2 {
                if !hold.handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            hold.dropTime = 0
            if timestamp - firedTime > firedTimeout {
                reset()
                return false
            }
            if activeCount == 2 {
                state = .holdDetected
                hold.holdDetectedTime = timestamp
            }
            return false
        }
    }

    func reset() {
        state = .idle
        hold.reset()
        pressStartTime = 0
        pressIsLeft = true
        firedTime = 0
    }
}
