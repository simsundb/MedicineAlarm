import Foundation
import AppKit

/// 一次待弹出的提醒。
struct AlarmFire: Identifiable {
    let id = UUID()
    let alarm: Alarm
    /// 这个闹钟原本该响的时刻（稍后提醒时保持不变，便于记账）
    let scheduled: Date
    /// 实际该弹出来的时刻
    let fireAt: Date
    /// 是用户点了「稍后提醒」后重新弹的
    let isSnooze: Bool
    /// 比原定时间晚了多久
    var lateness: TimeInterval { max(0, fireAt.timeIntervalSince(scheduled)) }
    /// 晚得比较多（不是精确到点），弹窗上要提示「补服」
    var isLate: Bool { !isSnooze && lateness > 90 }
}

/// 闹钟调度器：每秒检查一次，到点就通过 `onFire` 交给 UI 去弹窗。
///
/// 线程约定：本类所有方法都只在主线程调用（Timer 挂在 RunLoop.main，
/// NSWorkspace 的通知也在主线程派发），因此没有额外加锁。
final class Scheduler {

    private struct Snooze {
        let alarm: Alarm
        let scheduled: Date
        let fireAt: Date
    }

    private let store: AlarmStore
    private let log: DoseLog

    private var timer: Timer?
    private var activityToken: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    /// 已响过的闹钟：alarmID -> "yyyy-MM-dd HH:mm"，用来保证同一天同一个点只响一次。
    private var firedToday: [UUID: String] = [:]
    private var currentDay: String = ""
    /// 本次启动的时刻。早于这个时刻的闹钟不再回溯触发/记账——
    /// 应用没运行的那段时间它本来就观察不到，不该编造记录。
    private var sessionStart = Date()

    private var snoozes: [Snooze] = []
    /// 暂停提醒到某个时刻
    private var pausedUntil: Date?
    /// 心跳日志的时间戳，用来确认调度循环还活着
    private var lastHeartbeat = Date.distantPast

    /// 到点后还允许补弹的窗口。超过这个时长就只记一笔「已错过」，不再弹窗
    /// （避免电脑睡了一整天醒来后被一堆过期弹窗淹没）。可在设置里调整。
    var catchUpWindow: TimeInterval { Preferences.shared.catchUpWindowHours * 3600 }

    /// 今天是不是免打扰日。免打扰日既不弹窗也不记账。
    private var isSkipToday: Bool { Preferences.shared.isSkipToday }

    /// 到点回调。UI 层设置这个来弹窗。
    var onFire: ((AlarmFire) -> Void)?

    init(store: AlarmStore, log: DoseLog) {
        self.store = store
        self.log = log
    }

    // MARK: - 生命周期

    func start() {
        guard timer == nil else { return }
        sessionStart = Date()
        currentDay = DayKey.string(for: Date())

        // 后台应用的 Timer 会被 App Nap 降频，声明我们在做用户可感知的工作。
        //
        // 注意必须用 .userInitiatedAllowingIdleSystemSleep 而不是 .userInitiated：
        // 后者会带上 NSActivityIdleSystemSleepDisabled，等于让这台笔记本永远不进睡眠。
        // 睡眠期间错过的闹钟靠唤醒后的补服逻辑处理。
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "吃药闹钟需要按时触发"
        )

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common 模式：拖动窗口、菜单弹出时 Timer 也要继续走
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // 从睡眠中唤醒后立刻补检查一次
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tick()
        }

        tick()

        NSLog("[MedicineAlarm] 调度器已启动：\(store.alarms.count) 个闹钟（启用 \(store.alarms.filter(\.enabled).count)），会话起点 \(Self.stamp(sessionStart))")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
            self.activityToken = nil
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    // MARK: - 核心检查

    private func tick() {
        let now = Date()
        let day = DayKey.string(for: now)
        let calendar = Calendar.current

        // 跨天：清掉「今天已响过」的标记
        if day != currentDay {
            currentDay = day
            firedToday.removeAll()
        }

        let isPaused = pausedUntil.map { now < $0 } ?? false
        // 免打扰日：不弹窗、不记账。跟「暂停」走同一条分支，
        // 区别是暂停是临时的、免打扰日是按星期固定生效的。
        let isSilent = isPaused || isSkipToday

        // 心跳：确认 Timer 还在跑（后台应用最怕 Timer 被悄悄停掉）
        if now.timeIntervalSince(lastHeartbeat) >= 30 {
            lastHeartbeat = now
            NSLog("[MedicineAlarm] 心跳 \(Self.stamp(now))｜闹钟 \(store.alarms.count) 个｜静默中 \(isSilent)")
        }

        for alarm in store.alarms where alarm.enabled {
            let key = "\(day) \(alarm.timeString)"
            if firedToday[alarm.id] == key { continue }

            guard let scheduled = calendar.date(
                bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: now
            ) else { continue }

            // 还没到点，或者这个时间点早于本次启动（应用当时没在运行），都跳过
            guard now >= scheduled, scheduled >= sessionStart else { continue }

            firedToday[alarm.id] = key

            if isSilent {
                // 暂停 / 免打扰日期间到点：静默吞掉，恢复后不会一次性补弹一堆
                continue
            }

            if now.timeIntervalSince(scheduled) <= catchUpWindow {
                NSLog("[MedicineAlarm] 触发提醒 \(alarm.timeString) \(alarm.label)（晚了 \(Int(now.timeIntervalSince(scheduled))) 秒）")
                onFire?(AlarmFire(alarm: alarm, scheduled: scheduled, fireAt: now, isSnooze: false))
            } else {
                NSLog("[MedicineAlarm] 已错过 \(alarm.timeString) \(alarm.label)（晚了 \(Int(now.timeIntervalSince(scheduled) / 60)) 分钟，超出补服窗口）")
                log.record(.missed, alarm: alarm, scheduled: scheduled)
            }
        }

        // 稍后提醒
        var stillPending: [Snooze] = []
        for snooze in snoozes {
            if now >= snooze.fireAt {
                if isSilent {
                    continue  // 暂停 / 免打扰中，直接丢弃这次推迟
                }
                onFire?(AlarmFire(
                    alarm: snooze.alarm,
                    scheduled: snooze.scheduled,
                    fireAt: snooze.fireAt,
                    isSnooze: true
                ))
            } else {
                stillPending.append(snooze)
            }
        }
        snoozes = stillPending
    }

    // MARK: - 用户动作

    /// 用户点了「已服用」。
    func confirmTaken(_ fire: AlarmFire) {
        log.record(.taken, alarm: fire.alarm, scheduled: fire.scheduled)
    }

    /// 用户点了「稍后提醒」。
    func snooze(_ fire: AlarmFire, minutes: Int) {
        log.record(.snoozed, alarm: fire.alarm, scheduled: fire.scheduled)
        snoozes.append(Snooze(
            alarm: fire.alarm,
            scheduled: fire.scheduled,
            fireAt: Date().addingTimeInterval(Double(minutes) * 60)
        ))
    }

    /// 闹钟被修改后调用：把今天这个新时间点标记为已处理，
    /// 免得用户把时间改到「今天已经过去的时刻」时立刻弹一个窗。
    func markHandledToday(_ alarm: Alarm) {
        let day = DayKey.string(for: Date())
        let key = "\(day) \(alarm.timeString)"
        let calendar = Calendar.current
        if let scheduled = calendar.date(
            bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()
        ), scheduled <= Date() {
            firedToday[alarm.id] = key
        } else {
            // 时间点在将来，清掉旧标记以便正常触发
            firedToday.removeValue(forKey: alarm.id)
        }
    }

    // MARK: - 暂停

    func pause(for interval: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(interval)
    }

    func pauseUntilEndOfDay() {
        let calendar = Calendar.current
        pausedUntil = calendar.date(
            bySettingHour: 23, minute: 59, second: 59, of: Date()
        )
    }

    func resume() {
        pausedUntil = nil
    }

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return Date() < pausedUntil
    }

    var pausedUntilDate: Date? {
        isPaused ? pausedUntil : nil
    }

    // MARK: - 查询

    /// 日志里用的时间戳，只要时分秒
    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 下一个将要触发的闹钟（含稍后提醒）。菜单栏用它显示倒计时。
    func nextFire(after now: Date = Date()) -> (alarm: Alarm, date: Date)? {
        let calendar = Calendar.current

        // 待处理的稍后提醒优先级最高
        if let soonest = snoozes.map(\.fireAt).min(), soonest > now {
            if let snooze = snoozes.first(where: { $0.fireAt == soonest }) {
                return (snooze.alarm, soonest)
            }
        }

        let enabled = store.alarms.filter(\.enabled)
        guard !enabled.isEmpty else { return nil }

        // 从今天起逐天往后找，跳过免打扰日。
        // 最多看 9 天：就算七天全勾了，循环也会自然结束并返回 nil。
        for dayOffset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  !Preferences.shared.isSkipDay(day)
            else { continue }

            let candidates = enabled.compactMap { alarm -> (Alarm, Date)? in
                guard let d = calendar.date(
                    bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: day
                ), d > now else { return nil }
                return (alarm, d)
            }

            if let soonest = candidates.min(by: { $0.1 < $1.1 }) {
                return (soonest.0, soonest.1)
            }
        }

        return nil
    }

    /// 今天已服 / 总数，用于菜单栏进度。
    func todayProgress() -> (taken: Int, total: Int) {
        (log.takenCountToday(), store.alarms.filter(\.enabled).count)
    }
}
