import SwiftUI
import AppKit

/// A floating reference window showing all enabled gestures grouped by category.
struct CheatSheetView: View {

    @ObservedObject var config = GestureConfig.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2)
                Text("바로가기")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(GestureConfig.categories) { category in
                        let enabled = category.gestures.filter { config.uiIsEnabled($0.id) }
                        if !enabled.isEmpty {
                            cheatSection(title: category.title, icon: category.icon, gestures: enabled)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 360, height: 480)
    }

    private func cheatSection(title: String, icon: String, gestures: [GestureConfig.Info]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(gestures.enumerated()), id: \.element.id) { index, gesture in
                    HStack {
                        Text(gesture.name)
                            .font(.callout)
                        Spacer()
                        Text(actionText(for: gesture))
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    if index < gestures.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    /// Returns display text for the cheat sheet: zone actions if enabled, custom key, or default action.
    private func actionText(for gesture: GestureConfig.Info) -> String {
        if GestureConfig.zoneCapableGestures.contains(gesture.id) && config.zonesEnabled(for: gesture.id) {
            let leftAction = config.zoneAction(for: gesture.id, zone: .left) ?? config.actionFor(gesture.id)
            let rightAction = config.zoneAction(for: gesture.id, zone: .right) ?? config.actionFor(gesture.id)
            return "◀ \(leftAction.displayName) / \(rightAction.displayName) ▶"
        }
        let action = config.actionFor(gesture.id)
        if action == .custom {
            return formatCustomKey(gestureId: gesture.id)
        }
        return action.displayName
    }

    private func formatCustomKey(gestureId: String) -> String {
        let keyCode = UserDefaults.standard.integer(forKey: "customKey.\(gestureId).keyCode")
        let rawFlags = UserDefaults.standard.integer(forKey: "customKey.\(gestureId).flags")
        if keyCode == 0 && rawFlags == 0 { return "사용자 지정 (미설정)" }

        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawFlags))
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        parts.append(KeySynthesizer.keyCodeToString(UInt16(keyCode)))
        return parts.joined()
    }
}

// MARK: - Window Controller

final class CheatSheetWindowController {

    static let shared = CheatSheetWindowController()

    private var window: NSWindow?

    func show() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: CheatSheetView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "바로가기"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.setFrameAutosaveName("CheatSheetWindow")
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
