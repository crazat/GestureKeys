import Foundation

/// Recognizes two-finger hold + third finger swipe in four directions.
///
/// Detects which side the swiping finger is on:
/// - **Left side** (thumb for right-hand use):
///   - ← prev tab, → next tab, ↑ new window, ↓ minimize
/// - **Right side**:
///   - ← back, → forward, ↑ volume up / address bar, ↓ volume down
///
/// State machine:
/// ```
/// [Idle] → 2+ active stable 100ms → [HoldDetected]
/// [HoldDetected] → 3+ active, new finger detected → [Tracking]
/// [Tracking] → finger lifts with displacement → fire → [Idle]
/// ```
final class SwipeWhileHoldingRecognizer {

    enum State {
        case idle
        case holdDetected
        case tracking
    }

    enum Side { case left, right }

    private(set) var state: State = .idle

    private var holdStabilityDuration: TimeInterval { GestureConfig.shared.effectiveHoldStability }
    private var swipeThreshold: Float { GestureConfig.shared.effectiveSwipeThreshold(base: 0.06) }
    private let gracePeriod: TimeInterval = 0.080
    private let holdTimeout: TimeInterval = 10.0

    // Hold detection
    private var holdStartTime: TimeInterval = 0
    private var holdDetectedTime: TimeInterval = 0
    private var holdTracking = false
    private var dropTime: TimeInterval = 0
    private var holdAverageX: Float = 0
    private var holdPathIndices: Set<Int32> = []

    // Swipe tracking
    private var swipeSide: Side = .left
    private var swipePathIndex: Int32 = -1
    private var swipeStartX: Float = 0
    private var swipeStartY: Float = 0
    private var lastSwipeX: Float = 0
    private var lastSwipeY: Float = 0

    var isActive: Bool { state == .tracking }

    /// Returns true if a swipe action was fired this frame.
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
            }

            if activeCount >= 3 && !holdPathIndices.isEmpty {
                if let newFinger = activeTouches.first(where: { !holdPathIndices.contains($0.pathIndex) }) {
                    let newX = newFinger.normalizedVector.position.x
                    swipeSide = newX < holdAverageX ? .left : .right
                    swipePathIndex = newFinger.pathIndex
                    swipeStartX = newX
                    swipeStartY = newFinger.normalizedVector.position.y
                    lastSwipeX = swipeStartX
                    lastSwipeY = swipeStartY
                    state = .tracking
                }
            }
            return false

        case .tracking:
            if activeCount < 2 {
                if !handleGrace(timestamp: timestamp) { reset() }
                return false
            }
            dropTime = 0

            if activeCount > 3 { reset(); return false }

            if activeCount >= 3 {
                if let swipeFinger = activeTouches.first(where: { $0.pathIndex == swipePathIndex }) {
                    lastSwipeX = swipeFinger.normalizedVector.position.x
                    lastSwipeY = swipeFinger.normalizedVector.position.y
                    // Fire immediately when threshold is crossed (don't wait for lift)
                    let dx = lastSwipeX - swipeStartX
                    let dy = lastSwipeY - swipeStartY
                    if sqrt(dx * dx + dy * dy) >= swipeThreshold {
                        return checkAndFireSwipe()
                    }
                }
                return false
            }

            if activeCount == 2 {
                let swipeFingerLifted = !activeTouches.contains(where: { $0.pathIndex == swipePathIndex })
                if swipeFingerLifted {
                    return checkAndFireSwipe()
                } else {
                    reset()
                }
            }
            return false
        }
    }

    func reset() {
        state = .idle
        holdTracking = false
        holdStartTime = 0
        holdDetectedTime = 0
        dropTime = 0
        holdAverageX = 0
        holdPathIndices.removeAll(keepingCapacity: true)
        swipePathIndex = -1
        swipeStartX = 0
        swipeStartY = 0
        lastSwipeX = 0
        lastSwipeY = 0
        swipeSide = .left
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
                if dropTime == 0 {
                    dropTime = timestamp
                } else if timestamp - dropTime > gracePeriod {
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

    private func checkAndFireSwipe() -> Bool {
        let dx = lastSwipeX - swipeStartX
        let dy = lastSwipeY - swipeStartY
        let distance = sqrt(dx * dx + dy * dy)

        if distance < swipeThreshold {
            state = .holdDetected
            return false
        }

        // Require dominant axis to exceed minor axis by 2x to avoid
        // firing on diagonal/ambiguous movements.
        let dominantRatio: Float = 2.0
        let horizontal: Bool
        if abs(dx) > abs(dy) * dominantRatio {
            horizontal = true
        } else if abs(dy) > abs(dx) * dominantRatio {
            horizontal = false
        } else {
            // Ambiguous diagonal — don't fire, return to hold state
            state = .holdDetected
            return false
        }

        let config = GestureConfig.shared
        var didFire = false

        switch swipeSide {
        case .left:
            if horizontal {
                if dx < 0 { if config.isEnabled("swhLeft") { KeySynthesizer.fireAction(gestureId: "swhLeft"); didFire = true } }
                else       { if config.isEnabled("swhRight") { KeySynthesizer.fireAction(gestureId: "swhRight"); didFire = true } }
            } else {
                if dy > 0 { if config.isEnabled("swhUp") { KeySynthesizer.fireAction(gestureId: "swhUp"); didFire = true } }
                else       { if config.isEnabled("swhDown") { KeySynthesizer.fireAction(gestureId: "swhDown"); didFire = true } }
            }

        case .right:
            if horizontal {
                // Right-side horizontal swipe is unused (back/forward handled by TwoFingerSwipeRecognizer)
            } else {
                if dy > 0 {
                    if config.isEnabled("rightSwipeUp") { KeySynthesizer.fireAction(gestureId: "rightSwipeUp"); didFire = true }
                    else if config.isEnabled("rightSwipeUpDown") { KeySynthesizer.fireAction(gestureId: "rightSwipeUpDown", action: { KeySynthesizer.postVolumeUp() }); didFire = true }
                } else {
                    if config.isEnabled("rightSwipeUpDown") { KeySynthesizer.fireAction(gestureId: "rightSwipeUpDown", action: { KeySynthesizer.postVolumeDown() }); didFire = true }
                }
            }
        }

        // Preserve hold state for consecutive gestures (don't reset to idle)
        state = .holdDetected
        holdDetectedTime = ProcessInfo.processInfo.systemUptime
        swipePathIndex = -1
        dropTime = 0
        return didFire
    }
}
