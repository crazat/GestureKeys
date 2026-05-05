import AppKit

/// Floating HUD that briefly displays the recognized gesture name and action.
final class GestureHUD {

    static let shared = GestureHUD()

    private var panel: NSPanel?
    private var hideTimer: Timer?
    private var hudContentView: NSView?
    private var nameLabel: NSTextField?
    private var actionLabel: NSTextField?

    private init() {}

    /// Shows a HUD with the gesture name and action description.
    func show(name: String, action: String) {
        DispatchQueue.main.async { [weak self] in
            self?.presentHUD(name: name, action: action)
        }
    }

    private func presentHUD(name: String, action: String) {
        hideTimer?.invalidate()

        let panel = self.panel ?? createPanel()
        self.panel = panel

        if hudContentView == nil {
            let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 280, height: 52))
            blur.material = .hudWindow
            blur.state = .active
            blur.blendingMode = .behindWindow
            blur.wantsLayer = true
            blur.layer?.cornerRadius = 8
            blur.layer?.masksToBounds = true

            let cv = blur

            let nl = NSTextField(labelWithString: "")
            nl.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            nl.textColor = .labelColor
            nl.alignment = .center
            nl.frame = NSRect(x: 16, y: 26, width: 248, height: 18)

            let al = NSTextField(labelWithString: "")
            al.font = NSFont.systemFont(ofSize: 10)
            al.textColor = .secondaryLabelColor
            al.alignment = .center
            al.frame = NSRect(x: 16, y: 8, width: 248, height: 14)

            cv.addSubview(nl)
            cv.addSubview(al)

            hudContentView = cv
            nameLabel = nl
            actionLabel = al
        }

        nameLabel?.stringValue = name
        actionLabel?.stringValue = action
        panel.contentView = hudContentView

        // Position at bottom center of the screen containing the mouse cursor
        let screen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main
        if let screen {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 140
            let y = screenFrame.minY + 80
            panel.setFrame(NSRect(x: x, y: y, width: 280, height: 52), display: true)
        }

        panel.alphaValue = 1.0
        panel.orderFront(nil)

        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
        })
    }

    private func createPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}
