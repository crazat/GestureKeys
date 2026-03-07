import SwiftUI
import AppKit
import Combine

/// A floating window that shows real-time touch data and recognized gestures.
/// In monitor mode, actions are not actually executed.
struct GestureMonitorView: View {

    @StateObject private var monitor = GestureMonitor.shared
    @State private var viewMode: ViewMode = .log

    enum ViewMode: String, CaseIterable {
        case log = "로그"
        case heatmap = "히트맵"
    }

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

            // View mode picker
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            if viewMode == .log {
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
            } else {
                // Heatmap
                HeatmapView(grid: monitor.heatmapGrid)
                    .frame(height: 180)

                Button("히트맵 초기화") {
                    monitor.clearHeatmap()
                }
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 320, height: 440)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }
}

// MARK: - Heatmap View

struct HeatmapView: View {
    let grid: [[Int]]

    private let gridSize = 20

    var body: some View {
        Canvas { context, size in
            let maxVal = max(grid.flatMap { $0 }.max() ?? 1, 1)
            let cellW = size.width / CGFloat(gridSize)
            let cellH = size.height / CGFloat(gridSize)

            // Draw heatmap cells
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let value = grid[row][col]
                    guard value > 0 else { continue }
                    let intensity = min(Double(value) / Double(maxVal), 1.0)
                    let color = heatColor(intensity: intensity)
                    // Y-axis inverted: row 0 = bottom (trackpad y=0)
                    let displayRow = gridSize - 1 - row
                    let rect = CGRect(
                        x: CGFloat(col) * cellW,
                        y: CGFloat(displayRow) * cellH,
                        width: cellW,
                        height: cellH
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }

            // Draw palm rejection zone boundaries (orange dashed)
            let sideMargin = size.width * 0.30
            let topMargin = size.height * 0.20

            context.stroke(
                Path { path in
                    // Left boundary
                    path.move(to: CGPoint(x: sideMargin, y: 0))
                    path.addLine(to: CGPoint(x: sideMargin, y: size.height))
                    // Right boundary
                    path.move(to: CGPoint(x: size.width - sideMargin, y: 0))
                    path.addLine(to: CGPoint(x: size.width - sideMargin, y: size.height))
                    // Top boundary (near keyboard, y=0 in display = trackpad y=1)
                    path.move(to: CGPoint(x: 0, y: topMargin))
                    path.addLine(to: CGPoint(x: size.width, y: topMargin))
                },
                with: .color(.orange.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
        }
        .background(Color.black.opacity(0.05))
        .cornerRadius(4)
    }

    /// Maps intensity (0–1) to blue→yellow→red gradient.
    private func heatColor(intensity: Double) -> Color {
        if intensity < 0.5 {
            let t = intensity * 2
            return Color(red: t, green: t, blue: 1.0 - t)
        } else {
            let t = (intensity - 0.5) * 2
            return Color(red: 1.0, green: 1.0 - t, blue: 0)
        }
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
    @Published var heatmapGrid: [[Int]] = Array(repeating: Array(repeating: 0, count: 20), count: 20)

    /// Throttle state for touch size logging (prevents 60fps log flooding).
    /// Protected by monitorLock — written from touch callback, read/reset from main thread.
    private var monitorLock = os_unfair_lock()
    private var lastTouchLogTime: TimeInterval = 0
    private var lastLoggedTouchCount = 0
    private var lastHeatmapTime: TimeInterval = 0

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

    /// Records touch positions into the heatmap grid. Throttled to 100ms intervals.
    func recordHeatmapPositions(_ activeTouches: [MTTouch]) {
        guard !activeTouches.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        os_unfair_lock_lock(&monitorLock)
        if now - lastHeatmapTime < 0.100 {
            os_unfair_lock_unlock(&monitorLock)
            return
        }
        lastHeatmapTime = now
        os_unfair_lock_unlock(&monitorLock)

        // Compute grid increments on callback thread
        var increments: [(row: Int, col: Int)] = []
        for touch in activeTouches {
            let col = min(Int(touch.normalizedVector.position.x * 20), 19)
            let row = min(Int(touch.normalizedVector.position.y * 20), 19)
            increments.append((row: row, col: col))
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for inc in increments {
                self.heatmapGrid[inc.row][inc.col] += 1
            }
        }
    }

    func logTouchSizes(_ activeTouches: [MTTouch]) {
        let active = activeTouches
        guard !active.isEmpty else {
            os_unfair_lock_lock(&monitorLock)
            lastLoggedTouchCount = 0
            os_unfair_lock_unlock(&monitorLock)
            return
        }
        // Throttle: log only when touch count changes or max 1/sec
        let now = ProcessInfo.processInfo.systemUptime
        os_unfair_lock_lock(&monitorLock)
        if active.count == lastLoggedTouchCount && now - lastTouchLogTime < 1.0 {
            os_unfair_lock_unlock(&monitorLock)
            return
        }
        lastLoggedTouchCount = active.count
        lastTouchLogTime = now
        os_unfair_lock_unlock(&monitorLock)

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

    func clearHeatmap() {
        heatmapGrid = Array(repeating: Array(repeating: 0, count: 20), count: 20)
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
