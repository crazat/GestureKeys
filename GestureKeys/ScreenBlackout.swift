import AppKit
import CoreGraphics

/// Covers all screens with black windows. Dismisses on any keyboard or mouse input.
/// Unlike `pmset displaysleepnow`, this does NOT trigger the lock screen.
final class ScreenBlackout {

    static let shared = ScreenBlackout()

    private var windows: [BlackoutWindow] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    /// Brief cooldown so the triggering gesture's lift-off doesn't immediately dismiss.
    private var activationTime: TimeInterval = 0

    /// 1x1 transparent cursor image — created once and reused.
    private let invisibleCursor: NSCursor = {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        return NSCursor(image: image, hotSpot: .zero)
    }()

    private static let dismissEvents: NSEvent.EventTypeMask = [
        .keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown,
        .scrollWheel, .otherMouseDown
    ]

    private init() {}

    var isActive: Bool { !windows.isEmpty }

    func activate() {
        guard !isActive else { return }

        activationTime = ProcessInfo.processInfo.systemUptime

        // Create a black window for each screen
        for screen in NSScreen.screens {
            let win = BlackoutWindow(screenFrame: screen.frame, cursor: invisibleCursor)
            windows.append(win)
        }

        // Hide cursor at CG level + bring app to front
        CGDisplayHideCursor(CGMainDisplayID())
        NSApp.activate(ignoringOtherApps: true)

        // Local monitor — catches events sent to our blackout window (key window)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.dismissEvents) { [weak self] event in
            guard let self else { return event }
            if self.shouldDismiss() {
                self.deactivate()
                return nil  // consume the event
            }
            return event
        }

        // Global monitor — catches events from other apps (backup)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.dismissEvents) { [weak self] _ in
            guard let self else { return }
            if self.shouldDismiss() {
                self.deactivate()
            }
        }
    }

    private func shouldDismiss() -> Bool {
        let elapsed = ProcessInfo.processInfo.systemUptime - activationTime
        return elapsed > 0.5
    }

    func deactivate() {
        guard isActive else { return }

        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }

        for win in windows {
            win.orderOut(nil)
        }
        windows.removeAll()

        CGDisplayShowCursor(CGMainDisplayID())
    }
}

// MARK: - Blackout Window

/// Borderless black window that forces an invisible cursor via cursor rects.
private final class BlackoutWindow: NSWindow {

    init(screenFrame: NSRect, cursor: NSCursor) {
        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        isOpaque = true
        backgroundColor = .black
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = BlackoutView(cursor: cursor)
        view.frame = NSRect(origin: .zero, size: screenFrame.size)
        contentView = view

        orderFrontRegardless()
        makeKey()
    }

    // Allow this borderless window to become key (needed for local event monitor)
    override var canBecomeKey: Bool { true }
}

// MARK: - Blackout View

/// Sets an invisible cursor rect over the entire bounds.
private final class BlackoutView: NSView {

    private let invisibleCursor: NSCursor

    init(cursor: NSCursor) {
        self.invisibleCursor = cursor
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: invisibleCursor)
        invisibleCursor.set()
    }
}
