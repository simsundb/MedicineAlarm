import Foundation

/// 一个每日重复的吃药闹钟。
///
/// 时间用 hour/minute 两个 Int 表示（而不是 "HH:mm" 字符串），
/// 方便直接构造 DateComponents 和做排序比较。
struct Alarm: Codable, Identifiable, Hashable {
    var id: UUID
    /// 0-23
    var hour: Int
    /// 0-59
    var minute: Int
    /// 显示名，例如「激素服药」
    var label: String
    var enabled: Bool

    init(id: UUID = UUID(), hour: Int, minute: Int, label: String, enabled: Bool = true) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.enabled = enabled
    }

    /// "08:00"
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// 用于和「今天」组合成一个具体的触发时刻。
    var timeComponents: DateComponents {
        DateComponents(hour: hour, minute: minute, second: 0)
    }

    /// 把分钟数换算成便于排序的整数。
    var minutesSinceMidnight: Int { hour * 60 + minute }
}

extension Alarm {
    /// 本应用出厂自带的 7 个闹钟（时间与名称来自用户原有的配置）。
    static var defaults: [Alarm] {
        [
            Alarm(hour: 8, minute: 0, label: "激素服药"),
            Alarm(hour: 9, minute: 0, label: "排异服药"),
            Alarm(hour: 12, minute: 0, label: "服药提醒"),
            Alarm(hour: 15, minute: 0, label: "排异服药"),
            Alarm(hour: 18, minute: 0, label: "服药"),
            Alarm(hour: 20, minute: 0, label: "晚餐后服药"),
            Alarm(hour: 21, minute: 0, label: "睡前"),
        ]
    }
}
