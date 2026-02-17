import SwiftUI
import AppKit

/// An NSView-based key capture field that records keyCode + modifierFlags.
struct KeyCaptureView: NSViewRepresentable {

    let gestureId: String
    @Binding var keyCode: Int
    @Binding var modifierFlags: Int

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyCapture = { code, flags in
            keyCode = Int(code)
            modifierFlags = Int(flags.rawValue)
            // Persist
            UserDefaults.standard.set(keyCode, forKey: "customKey.\(gestureId).keyCode")
            UserDefaults.standard.set(modifierFlags, forKey: "customKey.\(gestureId).flags")
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {}
}

final class KeyCaptureNSView: NSView {

    var onKeyCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    private let label = NSTextField(labelWithString: "클릭 후 키 입력...")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        setFrameSize(NSSize(width: 180, height: 24))
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        label.stringValue = "키를 누르세요..."
        layer?.borderColor = NSColor.controlAccentColor.cgColor
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])
        onKeyCapture?(event.keyCode, flags)

        label.stringValue = formatKey(keyCode: event.keyCode, flags: flags)
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func resignFirstResponder() -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        return super.resignFirstResponder()
    }

    private func formatKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
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
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }

    func updateLabel(keyCode: Int, flags: Int) {
        if keyCode == 0 && flags == 0 {
            label.stringValue = "클릭 후 키 입력..."
        } else {
            label.stringValue = formatKey(
                keyCode: UInt16(keyCode),
                flags: NSEvent.ModifierFlags(rawValue: UInt(flags))
            )
        }
    }
}

/// SwiftUI wrapper showing the key capture field when `.custom` action is selected.
struct CustomKeySettingView: View {
    let gestureId: String
    @State private var keyCode: Int
    @State private var modifierFlags: Int

    init(gestureId: String) {
        self.gestureId = gestureId
        _keyCode = State(initialValue: UserDefaults.standard.integer(forKey: "customKey.\(gestureId).keyCode"))
        _modifierFlags = State(initialValue: UserDefaults.standard.integer(forKey: "customKey.\(gestureId).flags"))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("단축키:")
                .font(.caption)
                .foregroundColor(.secondary)
            KeyCaptureView(gestureId: gestureId, keyCode: $keyCode, modifierFlags: $modifierFlags)
                .frame(width: 180, height: 24)

            // Test button — fire the captured key combo
            Button(action: {
                guard keyCode != 0 || modifierFlags != 0 else { return }
                KeySynthesizer.postCustomKey(forGesture: gestureId)
            }) {
                Image(systemName: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("테스트")
            .disabled(keyCode == 0 && modifierFlags == 0)

            // Clear button — reset to unbound
            Button(action: {
                keyCode = 0
                modifierFlags = 0
                UserDefaults.standard.set(0, forKey: "customKey.\(gestureId).keyCode")
                UserDefaults.standard.set(0, forKey: "customKey.\(gestureId).flags")
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("초기화")
            .disabled(keyCode == 0 && modifierFlags == 0)
        }
    }
}
