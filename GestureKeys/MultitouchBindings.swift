import Foundation

// MARK: - MultitouchSupport.framework Private API Bindings

/// Opaque type representing a multitouch device
typealias MTDeviceRef = OpaquePointer

/// Contact frame callback signature.
/// Uses UnsafeMutableRawPointer for the touch array because MTTouch
/// contains tuple fields that aren't representable in @convention(c).
typealias MTContactFrameCallback = @convention(c) (
    MTDeviceRef,
    UnsafeMutableRawPointer,
    Int32,
    Double,
    Int32
) -> Void

// MARK: - Device Management

@_silgen_name("MTDeviceCreateList")
func MTDeviceCreateList() -> CFArray

@_silgen_name("MTDeviceStart")
func MTDeviceStart(_ device: MTDeviceRef, _ mode: Int32) -> Int32

@_silgen_name("MTDeviceStop")
func MTDeviceStop(_ device: MTDeviceRef) -> Int32

// MARK: - Callback Registration

@_silgen_name("MTRegisterContactFrameCallback")
func MTRegisterContactFrameCallback(
    _ device: MTDeviceRef,
    _ callback: MTContactFrameCallback
)

@_silgen_name("MTUnregisterContactFrameCallback")
func MTUnregisterContactFrameCallback(
    _ device: MTDeviceRef,
    _ callback: MTContactFrameCallback
)
