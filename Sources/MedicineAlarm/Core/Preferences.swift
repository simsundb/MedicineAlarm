import Foundation
import Combine

/// 用户偏好的唯一入口。
///
/// 所有 `UserDefaults` 键都收敛在这里，不让字符串字面量散落在
/// StatusBarController / PopupController / AlarmSound 里各写一遍——
/// 之前 `"speakEnabled"` 就在三个文件里各写了一次，加一个设置项要改四处。
///
/// 用单例是因为它本质就是一份全局配置；需要隔离测试时用 `init(defaults:)` 传自己的域。
final class Preferences: ObservableObject {

    static let shared = Preferences()

    /// 补服窗口的可选值（小时）
    static let catchUpOptions: [Double] = [0.5, 1, 2, 4, 8]

    /// 免打扰日的一个候选：星期几 + 它对应的 `Calendar.weekday` 值。
    ///
    /// 用 struct 而不是元组，是因为 KeyPath 取不到元组成员，
    /// `ForEach(_, id: \.weekday)` 会编译不过。
    struct WeekdayOption: Identifiable, Hashable {
        let label: String
        /// 跟 `Calendar.component(.weekday,)` 对齐：周日=1 … 周六=7
        let weekday: Int
        var id: Int { weekday }
    }

    /// 免打扰日的展示顺序：周一到周日。刻意不从周日起——中文习惯从周一开头。
    static let weekdayOptions: [WeekdayOption] = [
        WeekdayOption(label: "周一", weekday: 2),
        WeekdayOption(label: "周二", weekday: 3),
        WeekdayOption(label: "周三", weekday: 4),
        WeekdayOption(label: "周四", weekday: 5),
        WeekdayOption(label: "周五", weekday: 6),
        WeekdayOption(label: "周六", weekday: 7),
        WeekdayOption(label: "周日", weekday: 1),
    ]

    private enum Key {
        static let speakEnabled = "speakEnabled"
        static let chimeName = "chimeName"
        static let chimeInterval = "chimeInterval"
        static let catchUpHours = "catchUpWindowHours"
        static let skipWeekdays = "skipWeekdays"
    }

    private let defaults: UserDefaults

    /// 提醒弹出来时是否用中文念一遍闹钟名称
    @Published var speakEnabled: Bool {
        didSet { defaults.set(speakEnabled, forKey: Key.speakEnabled) }
    }

    /// 提示音名称，取自 `/System/Library/Sounds`
    @Published var chimeName: String {
        didSet { defaults.set(chimeName, forKey: Key.chimeName) }
    }

    /// 提醒期间提示音的重复间隔（秒）
    @Published var chimeInterval: Double {
        didSet { defaults.set(chimeInterval, forKey: Key.chimeInterval) }
    }

    /// 到点后还允许补弹的窗口（小时）。超出就只记一笔「已错过」，不再弹窗。
    @Published var catchUpWindowHours: Double {
        didSet { defaults.set(catchUpWindowHours, forKey: Key.catchUpHours) }
    }

    /// 免打扰日：这些星期几既不提醒、也不记「已错过」。
    ///
    /// 之所以要「按星期」而不是「按日期」，是因为中国的法定节假日和调休
    /// 由国务院逐年公告，没有任何系统 API 能算出来，写死在代码里明年就过期。
    /// 星期几是稳定可算的，正好覆盖「周末不开电脑」这个主要场景。
    @Published var skipWeekdays: Set<Int> {
        didSet { defaults.set(skipWeekdays.sorted(), forKey: Key.skipWeekdays) }
    }

    /// 今天是不是免打扰日
    var isSkipToday: Bool { isSkipDay() }

    func isSkipDay(_ date: Date = Date()) -> Bool {
        skipWeekdays.contains(Calendar.current.component(.weekday, from: date))
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // 直接初始化属性包装器的存储，而不是 `self.speakEnabled = ...`：
        // 这个写法不会触发 didSet，于是「没设置过」的键不会被写回磁盘，
        // 默认值（连同将来的改默认值）由这里单点兜底。
        self._speakEnabled = Published(
            initialValue: defaults.object(forKey: Key.speakEnabled) as? Bool ?? true
        )
        self._chimeName = Published(
            initialValue: defaults.string(forKey: Key.chimeName) ?? AlarmSound.defaultChimeName
        )
        self._chimeInterval = Published(
            initialValue: defaults.object(forKey: Key.chimeInterval) as? Double ?? 5
        )
        self._catchUpWindowHours = Published(
            initialValue: defaults.object(forKey: Key.catchUpHours) as? Double ?? 2
        )
        self._skipWeekdays = Published(
            initialValue: Self.decodeWeekdays(defaults.array(forKey: Key.skipWeekdays))
        )
    }

    /// 解析存下来的免打扰日。
    ///
    /// 不能直接 `as? [Int]`：`defaults write ... -array 1` 存进去的是字符串而不是数字，
    /// 那样写出来的配置会被整个丢掉。所以两种形式都认，并挡掉 1...7 之外的值。
    private static func decodeWeekdays(_ raw: [Any]?) -> Set<Int> {
        Set(
            (raw ?? []).compactMap { entry -> Int? in
                switch entry {
                case let n as Int:      return n
                case let n as NSNumber: return n.intValue
                case let s as String:   return Int(s)
                default:                return nil
                }
            }
            .filter { (1...7).contains($0) }
        )
    }
}
