import Foundation

/// 一条服药流水：某天某个闹钟被怎么处理了。
struct DoseRecord: Codable, Identifiable, Hashable {
    enum Status: String, Codable {
        /// 用户点了「已服用」
        case taken
        /// 用户点了「稍后提醒」
        case snoozed
        /// 到点时应用没在运行 / 电脑睡了太久，超过补服窗口
        case missed

        var displayName: String {
            switch self {
            case .taken:   return "已服用"
            case .snoozed: return "已推迟"
            case .missed:  return "已错过"
            }
        }

        var symbolName: String {
            switch self {
            case .taken:   return "checkmark.circle.fill"
            case .snoozed: return "clock.arrow.circlepath"
            case .missed:  return "exclamationmark.triangle.fill"
            }
        }
    }

    var id: UUID
    var alarmID: UUID
    var label: String
    /// "08:00" —— 这个闹钟原本该响的时间
    var scheduledTime: String
    /// "2026-09-16" —— 归属哪一天，方便按天分组
    var dayKey: String
    var status: Status
    var actedAt: Date

    init(
        id: UUID = UUID(),
        alarmID: UUID,
        label: String,
        scheduledTime: String,
        dayKey: String,
        status: Status,
        actedAt: Date = Date()
    ) {
        self.id = id
        self.alarmID = alarmID
        self.label = label
        self.scheduledTime = scheduledTime
        self.dayKey = dayKey
        self.status = status
        self.actedAt = actedAt
    }
}

// MARK: - 日期工具

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "2026-09-16"
    static func string(for date: Date) -> String {
        formatter.string(from: date)
    }
}
