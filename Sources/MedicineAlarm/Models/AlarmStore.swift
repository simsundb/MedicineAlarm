import Foundation
import Combine

/// 闹钟的持久化仓库。
///
/// 新配置路径：`~/Library/Application Support/MedicineAlarm/alarms.json`
/// 首次启动时若发现旧版 Python 程序的配置，会自动导入那 7 个闹钟及其名称。
final class AlarmStore: ObservableObject {

    @Published private(set) var alarms: [Alarm] = []

    private let configURL: URL
    /// 旧版 Python 程序的配置，只在首次启动时用来做一次导入。
    private let legacyConfigURL: URL

    /// 配置文件的落盘位置（自检 / 排查问题时打印用）
    var configPath: String { configURL.path }

    init(
        configURL: URL? = nil,
        legacyConfigURL: URL? = nil
    ) {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MedicineAlarm", isDirectory: true)

        self.configURL = configURL
            ?? support.appendingPathComponent("alarms.json")
        self.legacyConfigURL = legacyConfigURL
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".medicine_alarm/config.json")

        load()
    }

    // MARK: - 读取 / 写入

    private func load() {
        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded.sorted { $0.minutesSinceMidnight < $1.minutesSinceMidnight }
            return
        }

        // 新配置不存在（或已损坏）：尝试从旧版 Python 程序导入一次，否则用出厂默认。
        if let imported = importLegacyConfig(), !imported.isEmpty {
            alarms = imported
        } else {
            alarms = Alarm.defaults
        }
        save()
    }

    /// 读取 `~/.medicine_alarm/config.json`，格式形如：
    /// `{"version":1,"alarms":[{"time":"08:00","enabled":true,"label":"激素服药"}]}`
    private func importLegacyConfig() -> [Alarm]? {
        guard let data = try? Data(contentsOf: legacyConfigURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["alarms"] as? [[String: Any]]
        else { return nil }

        let parsed: [Alarm] = raw.compactMap { entry in
            guard let time = entry["time"] as? String else { return nil }
            let parts = time.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0...23).contains(hour), (0...59).contains(minute)
            else { return nil }

            return Alarm(
                hour: hour,
                minute: minute,
                label: (entry["label"] as? String)?.trimmingCharacters(in: .whitespaces).nilIfEmpty
                    ?? "服药提醒",
                enabled: (entry["enabled"] as? Bool) ?? true
            )
        }

        return parsed.sorted { $0.minutesSinceMidnight < $1.minutesSinceMidnight }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(alarms).write(to: configURL, options: .atomic)
        } catch {
            NSLog("[MedicineAlarm] 保存闹钟配置失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 增删改

    func add(hour: Int, minute: Int, label: String) {
        alarms.append(Alarm(hour: hour, minute: minute, label: label))
        sortAndSave()
    }

    func update(_ alarm: Alarm) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx] = alarm
        sortAndSave()
    }

    func delete(id: UUID) {
        alarms.removeAll { $0.id == id }
        save()
    }

    func delete(atOffsets offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        save()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[idx].enabled = enabled
        save()
    }

    private func sortAndSave() {
        alarms.sort { $0.minutesSinceMidnight < $1.minutesSinceMidnight }
        save()
    }

    var enabledCount: Int { alarms.filter(\.enabled).count }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
