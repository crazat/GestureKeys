import Foundation

/// Recognizes quick two-finger horizontal swipe for browser navigation.
///
/// - Swipe right → back (⌘[)
/// - Swipe left → forward (⌘])
///
/// Distinguished from scrolling by requiring:
/// - Primarily horizontal movement (|dx| > 2.5 × |dy|)
/// - Large displacement threshold (0.15 normalized)
/// - Fast completion (within 400ms)
///
/// State machine:
/// ```
/// [Idle] → 2 fingers active → [Tracking]
/// [Tracking] → displacement crosses threshold horizontally → fire → [Fired]
/// [Tracking] → timeout or non-horizontal → [Fired] (wait for lift)
/// [Fired] → all fingers lift → [Idle]
/// ```
final class TwoFingerSwipeRecognizer {

    enum State {
        case idle
        case tracking
        case fired
    }

    private(set) var state: State = .idle

    private var swipeThreshold: Float { GestureConfig.shared.effectiveSwipeThreshold(base: 0.15) }
    private let maxDuration: TimeInterval = 0.500
    private let horizontalRatio: Float = 2.5
    private let gracePeriod: TimeInterval = 0.080

    private var startTime: TimeInterval = 0
    private var dropTime: TimeInterval = 0
    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]

    var isActive: Bool { state != .idle }

    @discardableResult
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) -> Bool {
        let activeCount = activeTouches.count

        switch state {
        case .idle:
            // Only start tracking if both touches are quality (not peripheral/palm)
            let qualityTouches = activeTouches.filter { !$0.isTypingEdge && !$0.isPalmSized }
            if qualityTouches.count == 2 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in qualityTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                startTime = timestamp
                state = .tracking
            }

        case .tracking:
            if activeCount < 2 {
                // Grace period: allow brief finger lift
                if dropTime == 0 { dropTime = timestamp }
                else if timestamp - dropTime > gracePeriod { reset() }
                return false
            }
            if activeCount > 2 { reset(); return false }
            dropTime = 0
            if timestamp - startTime > maxDuration { state = .fired; return false }

            var totalDx: Float = 0
            var totalDy: Float = 0
            var matched = 0

            for touch in activeTouches {
                if let initial = initialPositions[touch.pathIndex] {
                    totalDx += touch.normalizedVector.position.x - initial.x
                    totalDy += touch.normalizedVector.position.y - initial.y
                    matched += 1
                }
            }

            guard matched == 2 else { reset(); return false }

            let avgDx = totalDx / 2.0
            let avgDy = totalDy / 2.0

            guard abs(avgDx) > abs(avgDy) * horizontalRatio else { return false }

            if abs(avgDx) >= swipeThreshold {
                if avgDx > 0 {
                    if GestureConfig.shared.isEnabled("twoFingerSwipeRight") {
                        KeySynthesizer.fireAction(gestureId: "twoFingerSwipeRight")
                    }
                } else {
                    if GestureConfig.shared.isEnabled("twoFingerSwipeLeft") {
                        KeySynthesizer.fireAction(gestureId: "twoFingerSwipeLeft")
                    }
                }
                state = .fired
                return true
            }

        case .fired:
            if activeCount == 0 { reset() }
        }

        return false
    }

    func reset() {
        state = .idle
        initialPositions.removeAll(keepingCapacity: true)
        dropTime = 0
        startTime = 0
    }
}
