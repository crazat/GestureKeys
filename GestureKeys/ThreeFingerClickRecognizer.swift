import Foundation

/// Recognizes three-finger physical click on trackpad → close tab (Cmd+W).
///
/// State machine:
/// ```
/// [Idle] → 3 active touches → [ThreeDown]
/// [ThreeDown] + physical click (via CGEventTap) → fire Cmd+W → [Cooldown]
/// [ThreeDown] + 4+ fingers → [Idle] (system gesture)
/// [ThreeDown] + fingers < 3 → [Idle] (after grace period)
/// [Cooldown] (200ms) → [Idle]
/// ```
///
/// Movement beyond threshold causes reset (swipe detection).
/// Grace period is extended (200ms) because physical clicking displaces fingers,
/// causing brief loss of 3-finger contact before the CGEventTap event arrives.
final class ThreeFingerClickRecognizer {

    enum State {
        case idle
        case threeDown
        case cooldown
    }

    private(set) var state: State = .idle

    /// Maximum normalized movement before we consider it a swipe
    private var moveThreshold: Float { GestureConfig.shared.effectiveMoveThreshold(base: 0.08) }

    /// Cooldown duration after firing (seconds)
    private let cooldownDuration: TimeInterval = 0.2

    /// Grace period for brief finger lift during click press.
    /// Physical clicking causes finger displacement — 200ms covers the CGEventTap latency.
    private let gracePeriod: TimeInterval = 0.200

    /// Initial positions when three fingers landed
    private var initialPositions: [Int32: (x: Float, y: Float)] = [:]

    /// Timestamp when cooldown started
    private var cooldownStart: TimeInterval = 0

    /// Timestamp when finger count dropped below target
    private var dropTime: TimeInterval = 0

    /// Number of currently active touches (updated each frame)
    private(set) var activeTouchCount: Int = 0

    /// Process a frame of touches.
    func processTouches(_ activeTouches: [MTTouch], timestamp: TimeInterval) {
        activeTouchCount = activeTouches.count

        switch state {
        case .idle:
            if activeTouches.count == 3 {
                initialPositions.removeAll(keepingCapacity: true)
                for touch in activeTouches {
                    initialPositions[touch.pathIndex] = (x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y)
                }
                state = .threeDown
            }

        case .threeDown:
            if activeTouches.count > 3 {
                state = .idle
                return
            }
            if activeTouches.count < 3 {
                // Grace period: allow brief finger lift during click press
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

    /// Called by GestureEngine when a physical click is detected via CGEventTap.
    /// Returns true if the click should be suppressed (gesture fired).
    func handlePhysicalClick() -> Bool {
        guard state == .threeDown else { return false }
        guard GestureConfig.shared.isEnabled("threeFingerClick") else {
            state = .idle
            return false
        }

        KeySynthesizer.fireAction(gestureId: "threeFingerClick")
        state = .cooldown
        cooldownStart = ProcessInfo.processInfo.systemUptime
        return true
    }

    func reset() {
        state = .idle
        initialPositions.removeAll(keepingCapacity: true)
        activeTouchCount = 0
        dropTime = 0
        cooldownStart = 0
    }

    // MARK: - Private

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
