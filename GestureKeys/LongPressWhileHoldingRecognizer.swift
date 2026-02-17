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

    private var holdStabilityDuration: TimeInterval { GestureConfig.shared.effectiveHoldStability }
    private var longPressDuration: TimeInterval { GestureConfig.shared.effectiveLongPressDuration(base: 0.400) }
    private let gracePeriod: TimeInterval = 0.080
    private let firedTimeout: TimeInterval = 5.0
    private let holdTimeout: TimeInterval = 10.0

    // Hold detection
    private var holdStartTime: TimeInterval = 0
    private var holdDetectedTime: TimeInterval = 0
    private var holdTracking = false
    private var holdConfirmed = false
    private var dropTime: TimeInterval = 0
    private var holdAverageX: Float = 0
    private var holdPathIndices: Set<Int32> = []

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
            handleIdle(activeTouches: activeTouches, timestamp: timestamp)
            return false

        case .holdDetected:
            if activeCount < 2 {
                if !handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            dropTime = 0
            if holdDetectedTime > 0 && timestamp - holdDetectedTime > holdTimeout {
                reset()
                return false
            }

            if activeCount == 2 {
                holdAverageX = activeTouches.reduce(Float(0)) { $0 + $1.normalizedVector.position.x } / 2.0
                holdPathIndices.removeAll(keepingCapacity: true)
                for touch in activeTouches { holdPathIndices.insert(touch.pathIndex) }
                holdConfirmed = true
            }

            if activeCount >= 3 && holdConfirmed && !holdPathIndices.isEmpty {
                if let newFinger = activeTouches.first(where: { !holdPathIndices.contains($0.pathIndex) }) {
                    let newX = newFinger.normalizedVector.position.x
                    pressIsLeft = newX < holdAverageX
                    pressStartTime = timestamp
                    state = .pressing
                }
            }
            return false

        case .pressing:
            if activeCount < 2 {
                if !handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            dropTime = 0

            if activeCount == 2 {
                // Finger lifted before threshold - was a tap, not long press
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
                if !handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            dropTime = 0
            if timestamp - firedTime > firedTimeout {
                reset()
                return false
            }
            if activeCount == 2 {
                state = .holdDetected
                holdDetectedTime = timestamp
            }
            return false
        }
    }

    func reset() {
        state = .idle
        holdTracking = false
        holdStartTime = 0
        holdDetectedTime = 0
        holdConfirmed = false
        dropTime = 0
        holdAverageX = 0
        holdPathIndices.removeAll(keepingCapacity: true)
        pressStartTime = 0
        pressIsLeft = true
        firedTime = 0
    }

    // MARK: - Private

    private func handleIdle(activeTouches: [MTTouch], timestamp: TimeInterval) {
        // Filter extreme edge/palm touches for hold detection
        // (wider typing-zone filter is handled by GestureEngine's twoFingerSuppressed)
        var qualityCount = 0
        for touch in activeTouches where !touch.isEdgeTouch && !touch.isPalmSized { qualityCount += 1 }
        if qualityCount >= 2 {
            if holdTracking {
                if timestamp - holdStartTime >= holdStabilityDuration {
                    state = .holdDetected
                    holdDetectedTime = timestamp
                }
            } else {
                holdTracking = true
                holdStartTime = timestamp
            }
        } else {
            if holdTracking {
                if dropTime == 0 { dropTime = timestamp }
                else if timestamp - dropTime > gracePeriod {
                    holdTracking = false
                    dropTime = 0
                }
            }
        }
    }

    private func handleGrace(timestamp: TimeInterval) -> Bool {
        if dropTime == 0 { dropTime = timestamp; return true }
        return timestamp - dropTime <= gracePeriod
    }
}
