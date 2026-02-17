import SwiftUI
import AppKit
import Combine

/// A floating window that shows real-time touch data and recognized gestures.
/// In monitor mode, actions are not actually executed.
struct GestureMonitorView: View {

    @StateObject private var monitor = GestureMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.point.up.braille")
                    .font(.title2)
                Text("제스처 테스트")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(monitor.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            Divider()

            // Touch count
            HStack {
                Text("활성 터치:")
                    .foregroundColor(.secondary)
                Text("\(monitor.activeTouchCount)")
                    .fontWeight(.medium)
                    .monospacedDigit()
                Spacer()
            }

            // Last recognized gesture
            if let last = monitor.lastGesture {
                VStack(alignment: .leading, spacing: 4) {
                    Text("마지막 인식된 제스처")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(last.name)
                            .fontWeight(.medium)
                        Text(last.action)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }

            // Log
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(monitor.log) { entry in
                            Text(entry.text)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .id(entry.id)
                        }
                    }
                }
                .frame(maxHeight: 150)
                .onChange(of: monitor.log.count) { _ in
                    if let last = monitor.log.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Button("로그 초기화") {
                monitor.clearLog()
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 320, height: 380)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }
}

// MARK: - Monitor State

final class GestureMonitor: ObservableObject {

    static let shared = GestureMonitor()

    struct LogEntry: Identifiable {
        let id = UUID()
        let text: String
    }

    struct GestureInfo {
        let name: String
        let action: String
    }

    @Published var activeTouchCount = 0
    @Published var lastGesture: GestureInfo?
    @Published var log: [LogEntry] = []
    @Published var isActive = false

    /// Throttle state for touch size logging (prevents 60fps log flooding)
    private var lastTouchLogTime: TimeInterval = 0
    private var lastLoggedTouchCount = 0

    private init() {}

    func start() {
        GestureEngine.monitorMode = true
        isActive = true
        addLog("테스트 모드 시작 — 제스처가 인식되지만 실행되지 않습니다")
    }

    func stop() {
        GestureEngine.monitorMode = false
        isActive = false
    }

    func recordGesture(id: String) {
        guard let info = GestureConfig.info(for: id) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.lastGesture = GestureInfo(name: info.name, action: info.action)
            self?.addLog("✓ \(info.name) → \(info.action)")
        }
    }

    func updateTouchCount(_ count: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.activeTouchCount = count
        }
    }

    func logTouchSizes(_ activeTouches: [MTTouch]) {
        let active = activeTouches
        guard !active.isEmpty else {
            lastLoggedTouchCount = 0
            return
        }
        // Throttle: log only when touch count changes or max 1/sec
        let now = ProcessInfo.processInfo.systemUptime
        if active.count == lastLoggedTouchCount && now - lastTouchLogTime < 1.0 {
            return
        }
        lastLoggedTouchCount = active.count
        lastTouchLogTime = now

        let sizes = active.map { String(format: "%.1f/%.1f%@%@",
            $0.majorAxis, $0.minorAxis,
            $0.isPalmSized ? " PALM" : "",
            $0.isEdgeTouch ? " EDGE" : "")
        }
        DispatchQueue.main.async { [weak self] in
            self?.addLog("터치[\(active.count)]: [\(sizes.joined(separator: ", "))]")
        }
    }

    func clearLog() {
        log.removeAll()
        lastGesture = nil
    }

    private func addLog(_ text: String) {
        let maxEntries = 100
        log.append(LogEntry(text: text))
        if log.count > maxEntries {
            log.removeFirst(log.count - maxEntries)
        }
    }
}

// MARK: - Window Controller

final class GestureMonitorWindowController {

    static let shared = GestureMonitorWindowController()

    private var window: NSWindow?

    func show() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: GestureMonitorView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "제스처 테스트"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
