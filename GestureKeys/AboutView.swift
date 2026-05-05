import SwiftUI

/// About window showing version info, credits, and update check.
struct AboutView: View {

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 16) {
            // App icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            // App name & version
            Text("GestureKeys")
                .font(.title.bold())

            HStack(spacing: 4) {
                Text("버전 \(version) (\(build))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("GestureKeys \(version) (\(build))", forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("버전 정보 복사")
            }

            Text("트랙패드 멀티터치 제스처를\n키보드 단축키로 매핑하는 유틸리티")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Links
            VStack(spacing: 8) {
                Link("GitHub", destination: URL(string: "https://github.com/crazat/GestureKeys")!)
                    .font(.body.weight(.medium))

                Link("개인정보 처리방침", destination: URL(string: "https://github.com/crazat/GestureKeys/blob/main/PRIVACY.md")!)
                    .font(.body.weight(.medium))
            }

            // Update button (only shown when Sparkle is configured)
            if UpdaterManager.shared.isConfigured {
                Button("업데이트 확인") {
                    UpdaterManager.shared.checkForUpdates()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            Text("Copyright © 2024-2026 GestureKeys")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(width: 320)
    }
}

/// Window controller for the About window.
final class AboutWindowController {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: AboutView())
        hostingView.setFrameSize(hostingView.fittingSize)

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "GestureKeys에 관하여"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}
