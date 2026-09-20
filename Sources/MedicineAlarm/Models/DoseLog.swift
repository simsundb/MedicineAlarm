import Foundation
import Combine

/// 服药流水的持久化仓库，落盘在 `~/Library/Application Support/MedicineAlarm/history.json`。
final class DoseLog: ObservableObject {

    private let fileURL: URL
    @Published private(set) var records: [DoseRecord] = []
    /// 流水只保留最近这么多天，避免文件无限增长。
    private let retentionDays = 180

    init(fileURL: URL? = nil) {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MedicineAlarm", isDirectory: true)
        self.fileURL = fileURL ?? support.appendingPathComponent("history.json")
        load()
    }

    // MARK: - 读取 / 写入

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DoseRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(records).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[MedicineAlarm] 保存服药记录失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 写入

    func record(_ status: DoseRecord.Status, alarm: Alarm, scheduled: Date, at actedAt: Date = Date()) {
        let entry = DoseRecord(
            alarmID: alarm.id,
            label: alarm.label,
            scheduledTime: alarm.timeString,
            dayKey: DayKey.string(for: scheduled),
            status: status,
            actedAt: actedAt
        )
        records.append(entry)
        prune()
        save()
    }

    private func prune() {
        guard let cutoff = Calendar.current.date(
            byAdding: .day, value: -retentionDays, to: Date()
        ) else { return }
        records.removeAll { $0.actedAt < cutoff }
    }

    // MARK: - 查询

    /// 某一天的流水，按计划时间排序。
    func records(on day: Date) -> [DoseRecord] {
        let key = DayKey.string(for: day)
        return records
            .filter { $0.dayKey == key }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    func todayRecords() -> [DoseRecord] {
        records(on: Date())
    }

    /// 今天已经确认服用的次数。
    func takenCountToday() -> Int {
        todayRecords().filter { $0.status == .taken }.count
    }

    /// 按天倒序的最近流水，用于「服药记录」窗口。
    func recentDays(limit: Int = 14) -> [(day: String, records: [DoseRecord])] {
        let grouped = Dictionary(grouping: records, by: \.dayKey)
        return grouped
            .sorted { $0.key > $1.key }
            .prefix(limit)
            .map { (day: $0.key, records: $0.value.sorted { $0.scheduledTime < $1.scheduledTime }) }
    }
}
