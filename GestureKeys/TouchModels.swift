import Foundation

// MARK: - Touch State

/// Multitouch finger state values from MultitouchSupport.framework
enum TouchState: Int32 {
    case notTracking = 0
    case starting    = 1
    case hovering    = 2
    case touching    = 3
    case active      = 4
    case lifting     = 5
    case lingering   = 6
    case outOfRange  = 7

    /// Whether this state represents a finger actively on the trackpad
    var isActive: Bool {
        switch self {
        case .touching, .active:
            return true
        default:
            return false
        }
    }
}

// MARK: - MTTouch C Struct Layout

/// 2D point in normalized coordinates (0.0 - 1.0)
struct MTPoint {
    var x: Float
    var y: Float
}

/// 2D vector with position and velocity
struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

/// Matches the C memory layout of the MTTouch struct from MultitouchSupport.framework.
/// Total size: 96 bytes (stride 96, aligned to 8 for Double).
struct MTTouch {
    var frame: Int32               // offset 0   (4 bytes)
    var timestamp: Double          // offset 8   (8 bytes, 4 bytes padding before)
    var pathIndex: Int32           // offset 16  (4 bytes) - touch path identifier
    var state: Int32               // offset 20  (4 bytes)
    var fingerID: Int32            // offset 24  (4 bytes)
    var handID: Int32              // offset 28  (4 bytes)
    var normalizedVector: MTVector // offset 32  (16 bytes: pos.x, pos.y, vel.x, vel.y)
    var zTotal: Float              // offset 48  (4 bytes)
    var pressure: Float            // offset 52  (4 bytes)
    var angle: Float               // offset 56  (4 bytes)
    var majorAxis: Float           // offset 60  (4 bytes)
    var minorAxis: Float           // offset 64  (4 bytes)
    var absoluteVector: MTVector   // offset 68  (16 bytes)
    var _field14: Int32            // offset 84  (4 bytes)
    var _field15: Int32            // offset 88  (4 bytes)
    var zDensity: Float            // offset 92  (4 bytes)
    // total: 96 bytes

    // Compile-time verification: MTTouch must be exactly 96 bytes to match
    // the C struct layout from MultitouchSupport.framework.
    static let _sizeCheck: Void = {
        precondition(MemoryLayout<MTTouch>.size == 96,
               "MTTouch size mismatch: expected 96, got \(MemoryLayout<MTTouch>.size)")
        precondition(MemoryLayout<MTTouch>.stride == 96,
               "MTTouch stride mismatch: expected 96, got \(MemoryLayout<MTTouch>.stride)")
    }()

    var touchState: TouchState {
        TouchState(rawValue: state) ?? .notTracking
    }

    /// Whether this touch is at the extreme edge of the trackpad,
    /// where palm contact commonly occurs. Edge margin: 3% from each side.
    var isEdgeTouch: Bool {
        let margin: Float = 0.03
        let pos = normalizedVector.position
        return pos.x < margin || pos.x > (1.0 - margin) ||
               pos.y < margin || pos.y > (1.0 - margin)
    }

    /// Whether this touch is in the peripheral zone where palm/thumb contact
    /// occurs during typing. Optimized for typing posture:
    /// - Sides: 30% — palm/thumb edges
    /// - Top (y≈1, near keyboard): 20% — thumbs/palms rest here
    /// - Bottom (y≈0, far from keyboard): no margin — palms never reach here
    ///
    /// ```
    /// y=1.0 (keyboard)   ┌─ top 20% ──────────────┐
    ///                     │ 30% │ center 40% │ 30% │
    ///                     │ 30% │ center 40% │ 30% │
    /// y=0.0 (user)        └────────────────────────┘
    /// ```
    var isTypingEdge: Bool {
        let pos = normalizedVector.position
        let sideMargin: Float = 0.30
        let topMargin: Float = 0.20
        return pos.x < sideMargin || pos.x > (1.0 - sideMargin) ||
               pos.y > (1.0 - topMargin)
    }

    /// Whether this touch is likely a palm based on contact size.
    /// Palm contacts tend to have a large major axis (> 10mm normalized).
    var isPalmSized: Bool {
        majorAxis > 10.0
    }
}

// MARK: - Trackpad Zone

/// Left/right zone classification based on normalized x coordinate.
enum TrackpadZone: String {
    case left
    case right

    /// Determines zone from a normalized x coordinate (0.0–1.0).
    static func from(x: Float) -> TrackpadZone {
        x < 0.5 ? .left : .right
    }
}

extension MTTouch {
    /// The trackpad zone this touch falls in.
    var zone: TrackpadZone {
        TrackpadZone.from(x: normalizedVector.position.x)
    }
}

// MARK: - Shared Movement Detection

/// Checks if any touch has moved beyond a threshold from its initial position.
/// Used by click/tap/long-press recognizers to distinguish taps from swipes.
/// - Parameters:
///   - activeTouches: Current active touches
///   - initialPositions: Dictionary mapping pathIndex to initial (x, y)
///   - threshold: Maximum allowed movement (normalized, squared comparison)
/// - Returns: True if any tracked touch exceeded the threshold
func hasExcessiveMovement(_ activeTouches: [MTTouch],
                          initialPositions: [Int32: (x: Float, y: Float)],
                          threshold: Float) -> Bool {
    let thresholdSq = threshold * threshold
    for touch in activeTouches {
        if let initial = initialPositions[touch.pathIndex] {
            let dx = touch.normalizedVector.position.x - initial.x
            let dy = touch.normalizedVector.position.y - initial.y
            if dx * dx + dy * dy > thresholdSq {
                return true
            }
        }
    }
    return false
}

/// Single-finger variant for recognizers that track one hold finger's initial position.
/// Used by OneFingerHoldTap and OneFingerHoldSwipe recognizers.
func hasExcessiveMovement(_ finger: MTTouch,
                          initialX: Float, initialY: Float,
                          threshold: Float) -> Bool {
    let dx = finger.normalizedVector.position.x - initialX
    let dy = finger.normalizedVector.position.y - initialY
    return dx * dx + dy * dy > threshold * threshold
}

/// Array-based variant for recognizers that store initial positions as tuples.
func hasExcessiveMovement(_ activeTouches: [MTTouch],
                          initialPositions: [(pathIndex: Int32, x: Float, y: Float)],
                          threshold: Float) -> Bool {
    let thresholdSq = threshold * threshold
    for touch in activeTouches {
        if let initial = initialPositions.first(where: { $0.pathIndex == touch.pathIndex }) {
            let dx = touch.normalizedVector.position.x - initial.x
            let dy = touch.normalizedVector.position.y - initial.y
            if dx * dx + dy * dy > thresholdSq {
                return true
            }
        }
    }
    return false
}
