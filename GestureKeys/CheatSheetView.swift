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

    /// Returns display text for the cheat sheet: custom key binding if set, otherwise default action.
    private func actionText(for gesture: GestureConfig.Info) -> String {
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

        let keyMap: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
            0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q",
            0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1",
            0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
            0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P", 0x24: "Return",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";", 0x2A: "\\",
            0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M", 0x2F: ".",
            0x30: "Tab", 0x31: "Space", 0x33: "Delete", 0x35: "Esc",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        ]
        parts.append(keyMap[UInt16(keyCode)] ?? "Key\(keyCode)")
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
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
