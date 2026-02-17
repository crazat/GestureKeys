import Foundation

/// Recognizes quick three-finger swipe for tab navigation and page scroll.
///
/// - Swipe right → next tab (⇧⌘])
/// - Swipe left → previous tab (⇧⌘[)
/// - Swipe up → page top (⌘↑)
/// - Swipe down → page bottom (⌘↓)
///
/// Distinguished from 3-finger click/long-press by requiring:
/// - Primarily directional movement (dominant axis > 2.5 × minor axis)
/// - Displacement threshold (0.10 normalized)
/// - Fast completion (within 400ms)
final class ThreeFingerSwipeRecognizer {

    enum State {
        case idle
        case tracking
        case fired
    }

    private(set) var state: State = .idle

    private var swipeThreshold: Float { GestureConfig.shared.effectiveSwipeThreshold(base: 0.10) }
    private let maxDuration: TimeInterval = 0.400
    private let directionRatio: Float = 2.5
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
            if activeCount == 3 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                startTime = timestamp
                state = .tracking
            }

        case .tracking:
            if activeCount < 3 {
                if dropTime == 0 { dropTime = timestamp }
                else if timestamp - dropTime > gracePeriod { reset() }
                return false
            }
            if activeCount > 3 { reset(); return false }
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

            guard matched == 3 else { reset(); return false }

            let avgDx = totalDx / 3.0
            let avgDy = totalDy / 3.0

            // Horizontal swipe
            if abs(avgDx) > abs(avgDy) * directionRatio && abs(avgDx) >= swipeThreshold {
                if avgDx > 0 {
                    if GestureConfig.shared.isEnabled("threeFingerSwipeRight") {
                        KeySynthesizer.fireAction(gestureId: "threeFingerSwipeRight")
                    }
                } else {
                    if GestureConfig.shared.isEnabled("threeFingerSwipeLeft") {
                        KeySynthesizer.fireAction(gestureId: "threeFingerSwipeLeft")
                    }
                }
                state = .fired
                return true
            }

            // Vertical swipe (trackpad Y: positive = toward user = down)
            if abs(avgDy) > abs(avgDx) * directionRatio && abs(avgDy) >= swipeThreshold {
                if avgDy < 0 {
                    if GestureConfig.shared.isEnabled("threeFingerSwipeUp") {
                        KeySynthesizer.fireAction(gestureId: "threeFingerSwipeUp")
                    }
                } else {
                    if GestureConfig.shared.isEnabled("threeFingerSwipeDown") {
                        KeySynthesizer.fireAction(gestureId: "threeFingerSwipeDown")
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
