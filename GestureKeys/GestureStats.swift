import Foundation

/// Lightweight gesture usage statistics tracker.
/// Records gesture fire events with daily aggregation, persisted via UserDefaults.
final class GestureStats {

    static let shared = GestureStats()

    /// Single day's aggregated counts per gesture.
    struct DailyRecord: Codable {
        var date: String  // "yyyy-MM-dd"
        var counts: [String: Int]  // gestureId → count
    }

    /// A usage recommendation for the user.
    struct Recommendation: Identifiable {
        enum Kind { case unused, ergonomic }
        let id = UUID()
        let type: Kind
        let message: String
        let gestureId: String
        let suggestedGestureId: String?
    }

    private let defaults = UserDefaults.standard
    private let storageKey = "gestureStats.daily"
    private let maxDays = 30

    private var records: [DailyRecord] = []
    private var lock = os_unfair_lock()
    private var isDirty = false

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        loadRecords()
    }

    // MARK: - Recording

    /// Record a gesture fire event. Thread-safe.
    /// Persistence is batched — writes are flushed after a 5-second debounce or on app termination.
    func record(gestureId: String) {
        os_unfair_lock_lock(&lock)

        let today = dateFormatter.string(from: Date())

        if let index = records.firstIndex(where: { $0.date == today }) {
            records[index].counts[gestureId, default: 0] += 1
        } else {
            records.append(DailyRecord(date: today, counts: [gestureId: 1]))
            pruneOldRecords()
        }

        let needsSchedule = !isDirty
        isDirty = true
        os_unfair_lock_unlock(&lock)

        if needsSchedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.flushIfNeeded()
            }
        }
    }

    /// Flushes pending changes to UserDefaults. Call on app termination.
    func flushIfNeeded() {
        os_unfair_lock_lock(&lock)
        guard isDirty else { os_unfair_lock_unlock(&lock); return }
        isDirty = false
        let data = try? JSONEncoder().encode(records)
        os_unfair_lock_unlock(&lock)
        if let data { defaults.set(data, forKey: storageKey) }
    }

    // MARK: - Queries

    /// Total counts per gesture for the last N days.
    func totals(days: Int = 7) -> [String: Int] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        let cutoffDate = Date().addingTimeInterval(-Double(days) * 86400)
        var result: [String: Int] = [:]
        for record in records {
            guard let recordDate = dateFormatter.date(from: record.date), recordDate >= cutoffDate else { continue }
            for (gestureId, count) in record.counts {
                result[gestureId, default: 0] += count
            }
        }
        return result
    }

    /// Daily counts for a specific gesture over the last N days.
    func dailyCounts(for gestureId: String, days: Int = 7) -> [(date: String, count: Int)] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        let cutoffDate = Date().addingTimeInterval(-Double(days) * 86400)
        var result: [(date: String, count: Int)] = []
        for record in records {
            guard let recordDate = dateFormatter.date(from: record.date), recordDate >= cutoffDate else { continue }
            result.append((date: record.date, count: record.counts[gestureId] ?? 0))
        }
        return result
    }

    /// Top N gestures by total count in the last N days.
    func topGestures(count: Int = 5, days: Int = 7) -> [(gestureId: String, count: Int)] {
        let t = totals(days: days)
        return t.sorted { $0.value > $1.value }.prefix(count).map { ($0.key, $0.value) }
    }

    /// Total fire count across all gestures for the last N days.
    func totalFires(days: Int = 7) -> Int {
        totals(days: days).values.reduce(0, +)
    }

    /// Clear all statistics.
    func clearAll() {
        os_unfair_lock_lock(&lock)
        records.removeAll()
        isDirty = false
        os_unfair_lock_unlock(&lock)
        defaults.removeObject(forKey: storageKey)
    }

    // MARK: - Recommendations

    /// Simpler gesture alternatives for complex gestures.
    private static let ergonomicAlternatives: [String: (suggestedId: String, message: String)] = [
        "threeFingerTripleTap": ("threeFingerDoubleTap", "트리플탭 대신 더블탭을 더블 사용하면 편합니다"),
        "fiveFingerLongPress": ("fiveFingerTap", "5손가락 길게 누르기 대신 5손가락 탭이 더 빠릅니다"),
        "fourFingerLongPress": ("fourFingerDoubleTap", "4손가락 길게 누르기 대신 더블탭이 더 빠릅니다"),
    ]

    /// Generates usage-based recommendations.
    func generateRecommendations() -> [Recommendation] {
        let weekTotals = totals(days: 7)
        let config = GestureConfig.shared
        var recommendations: [Recommendation] = []

        // 1. Unused enabled gestures (enabled for 7+ days but never used)
        for info in GestureConfig.all {
            if config.uiIsEnabled(info.id) && (weekTotals[info.id] ?? 0) == 0 {
                recommendations.append(Recommendation(
                    type: .unused,
                    message: "\"\(info.name)\"이(가) 활성화되어 있지만 7일간 사용되지 않았습니다. 비활성화를 고려해보세요.",
                    gestureId: info.id,
                    suggestedGestureId: nil
                ))
            }
        }

        // 2. Ergonomic alternatives for frequently used complex gestures
        for (gestureId, alt) in Self.ergonomicAlternatives {
            let count = weekTotals[gestureId] ?? 0
            if count >= 10 && config.uiIsEnabled(gestureId) {
                recommendations.append(Recommendation(
                    type: .ergonomic,
                    message: alt.message,
                    gestureId: gestureId,
                    suggestedGestureId: alt.suggestedId
                ))
            }
        }

        return recommendations
    }

    // MARK: - Persistence

    private func loadRecords() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            records = try JSONDecoder().decode([DailyRecord].self, from: data)
        } catch {
            NSLog("GestureKeys: Failed to decode stats data: %@", error.localizedDescription)
        }
    }

    private func pruneOldRecords() {
        if records.count > maxDays {
            records = Array(records.suffix(maxDays))
        }
    }
}
