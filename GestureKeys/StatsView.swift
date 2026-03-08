import SwiftUI

/// Statistics dashboard showing gesture usage patterns.
struct StatsView: View {

    @State private var totals: [String: Int] = [:]
    @State private var topGestures: [(gestureId: String, count: Int)] = []
    @State private var totalFires: Int = 0
    @State private var selectedDays: Int = 7
    @State private var recommendations: [GestureStats.Recommendation] = []
    @State private var dismissedRecommendations: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("제스처 통계")
                    .font(.headline)
                Spacer()
                Picker("기간", selection: $selectedDays) {
                    Text("7일").tag(7)
                    Text("14일").tag(14)
                    Text("30일").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                Button(action: clearStats) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("통계 초기화")
            }
            .padding()

            Divider()

            if totalFires == 0 {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("아직 기록된 제스처가 없습니다")
                        .foregroundColor(.secondary)
                    Text("제스처를 사용하면 여기에 통계가 표시됩니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Recommendations
                        if !visibleRecommendations.isEmpty {
                            recommendationsSection
                        }

                        // Summary
                        summarySection

                        Divider()

                        // Top gestures bar chart
                        if !topGestures.isEmpty {
                            topGesturesSection
                        }

                        Divider()

                        // All gestures table
                        allGesturesSection
                    }
                    .padding()
                }
            }
        }
        .frame(width: 480, height: 500)
        .onAppear(perform: refresh)
        .onChange(of: selectedDays) { _ in refresh() }
    }

    private var visibleRecommendations: [GestureStats.Recommendation] {
        recommendations.filter { !dismissedRecommendations.contains($0.id) }
    }

    // MARK: - Sections

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("추천")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(visibleRecommendations) { rec in
                HStack(spacing: 8) {
                    if rec.type == .unused {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(.blue)
                    }

                    Text(rec.message)
                        .font(.caption)
                        .lineLimit(3)

                    Spacer()

                    Button(action: { dismissedRecommendations.insert(rec.id) }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(rec.type == .unused ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    private var summarySection: some View {
        HStack(spacing: 24) {
            StatCard(title: "총 사용 횟수", value: "\(totalFires)", icon: "hand.tap")
            StatCard(title: "활성 제스처", value: "\(totals.count)", icon: "rectangle.grid.2x2")
            StatCard(title: "일 평균", value: "\(totalFires / max(selectedDays, 1))", icon: "chart.line.uptrend.xyaxis")
        }
    }

    private var topGesturesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("가장 많이 사용한 제스처")
                .font(.subheadline)
                .foregroundColor(.secondary)

            let maxCount = topGestures.first?.count ?? 1

            ForEach(topGestures, id: \.gestureId) { item in
                HStack(spacing: 8) {
                    Text(gestureName(for: item.gestureId))
                        .frame(width: 140, alignment: .trailing)
                        .font(.caption)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: item.gestureId))
                            .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(max(maxCount, 1)))
                    }
                    .frame(height: 18)

                    Text("\(item.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private var allGesturesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("전체 제스처 사용 내역")
                .font(.subheadline)
                .foregroundColor(.secondary)

            let sorted = totals.sorted { $0.value > $1.value }

            ForEach(sorted, id: \.key) { gestureId, count in
                HStack {
                    Text(gestureName(for: gestureId))
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text("\(count)회")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func refresh() {
        totals = GestureStats.shared.totals(days: selectedDays)
        topGestures = GestureStats.shared.topGestures(count: 5, days: selectedDays)
        totalFires = GestureStats.shared.totalFires(days: selectedDays)
        recommendations = GestureStats.shared.generateRecommendations()
        dismissedRecommendations.removeAll()
    }

    private func clearStats() {
        GestureStats.shared.clearAll()
        refresh()
    }

    private func gestureName(for gestureId: String) -> String {
        GestureConfig.info(for: gestureId)?.name ?? gestureId
    }

    private func barColor(for gestureId: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        let hash = abs(gestureId.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Window controller for displaying the stats dashboard.
final class StatsWindowController {
    static let shared = StatsWindowController()
    private var windowController: NSWindowController?

    func show() {
        if let wc = windowController {
            wc.showWindow(nil)
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "제스처 통계"
        window.setFrameAutosaveName("StatsWindow")
        window.center()
        window.contentView = NSHostingView(rootView: StatsView())

        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windowController = wc
    }
}
