import Foundation

/// Shared two-finger hold detection logic used by TapWhileHolding, SwipeWhileHolding,
/// and LongPressWhileHolding recognizers. Tracks when 2 quality fingers are stable
/// for the configured hold stability duration.
struct TwoFingerHoldDetector {

    private var holdTracking = false
    private var holdStartTime: TimeInterval = 0
    var holdDetectedTime: TimeInterval = 0
    var dropTime: TimeInterval = 0
    var holdAverageX: Float = 0

    /// Whether exactly 2 fingers have been confirmed (prevents false activation
    /// when 3+ fingers are placed simultaneously).
    var holdConfirmed = false

    /// Path indices of the held fingers.
    var holdPathIndices: Set<Int32> = []

    let gracePeriod: TimeInterval = 0.080
    let holdTimeout: TimeInterval = 10.0

    /// Process idle state: returns true when hold is detected.
    mutating func processIdle(activeTouches: [MTTouch], timestamp: TimeInterval,
                              holdStabilityDuration: TimeInterval) -> Bool {
        var qualityCount = 0
        for touch in activeTouches where !touch.isEdgeTouch && !touch.isPalmSized { qualityCount += 1 }
        if qualityCount >= 2 {
            if holdTracking {
                if timestamp - holdStartTime >= holdStabilityDuration {
                    holdDetectedTime = timestamp
                    return true
                }
            } else {
                holdTracking = true
                holdStartTime = timestamp
            }
        } else {
            if holdTracking {
                if dropTime == 0 {
                    dropTime = timestamp
                } else if timestamp - dropTime > gracePeriod {
                    holdTracking = false
                    dropTime = 0
                }
            }
        }
        return false
    }

    /// Returns true if we're still within the grace period (don't reset yet).
    mutating func handleGrace(timestamp: TimeInterval) -> Bool {
        if dropTime == 0 { dropTime = timestamp; return true }
        return timestamp - dropTime <= gracePeriod
    }

    /// Updates hold average X and path indices from current active touches.
    mutating func updateHoldPosition(_ activeTouches: [MTTouch]) {
        let count = max(Float(activeTouches.count), 1)
        holdAverageX = activeTouches.reduce(Float(0)) { $0 + $1.normalizedVector.position.x } / count
        holdPathIndices.removeAll(keepingCapacity: true)
        for touch in activeTouches { holdPathIndices.insert(touch.pathIndex) }
    }

    /// Checks if hold has timed out.
    func isTimedOut(timestamp: TimeInterval) -> Bool {
        holdDetectedTime > 0 && timestamp - holdDetectedTime > holdTimeout
    }

    mutating func reset() {
        holdTracking = false
        holdStartTime = 0
        holdDetectedTime = 0
        holdConfirmed = false
        dropTime = 0
        holdAverageX = 0
        holdPathIndices.removeAll(keepingCapacity: true)
    }
}
