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
