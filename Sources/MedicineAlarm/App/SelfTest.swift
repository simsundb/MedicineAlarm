import AppKit
import Foundation

/// `--self-test` 模式：启动后自动跑一遍关键路径并把结果打到 stderr，然后退出。
///
/// 用途是在没有人盯着屏幕的情况下确认「弹窗真的弹得出来、声音真的能加载、
/// 调度算得对」，而不是靠肉眼。
/// 正常使用时不会走到这里。
enum SelfTest {

    private static func out(_ message: String) {
        FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    }

    static func run(
        store: AlarmStore,
        log: DoseLog,
        scheduler: Scheduler,
        popup: PopupController
    ) {
        out("===== 自检开始 =====")

        // 1. 配置
        out("[配置] 文件: \(store.configPath)")
        out("[配置] 闹钟 \(store.alarms.count) 个，启用 \(store.enabledCount) 个")
        for alarm in store.alarms {
            out("        \(alarm.timeString)  \(alarm.label)  [\(alarm.enabled ? "启用" : "停用")]")
        }

        // 2. 落盘是否真的写成功
        let configExists = FileManager.default.fileExists(atPath: store.configPath)
        out("[配置] 已写入磁盘: \(configExists ? "是" : "否")")

        // 3. 调度
        if let next = scheduler.nextFire() {
            let seconds = Int(next.date.timeIntervalSinceNow)
            out("[调度] 下一个: \(next.alarm.timeString) \(next.alarm.label)，\(seconds) 秒后")
        } else {
            out("[调度] ⚠️ 没有启用中的闹钟，算不出下一个触发时间")
        }

        // 4. 声音
        let chimeName = Preferences.shared.chimeName
        let systemSound = NSSound(named: NSSound.Name(chimeName))
        out("[声音] 提示音 \(chimeName): \(systemSound != nil ? "可用" : "不可用")")
        out("[声音] 间隔 \(Int(Preferences.shared.chimeInterval)) 秒｜语音播报 \(Preferences.shared.speakEnabled ? "开" : "关")")

        // 5. 免打扰 / 补服窗口
        let skipLabels = Preferences.weekdayOptions
            .filter { Preferences.shared.skipWeekdays.contains($0.weekday) }
            .map(\.label)
        out("[免打扰] \(skipLabels.isEmpty ? "每天都提醒" : "跳过 " + skipLabels.joined(separator: "、"))")
        out("[免打扰] 今天\(Preferences.shared.isSkipToday ? "是" : "不是")免打扰日")
        out("[补服] 窗口 \(Preferences.shared.catchUpWindowHours) 小时")

        // 6. 开机自启
        out("[自启] 当前状态: \(LoginItem.isEnabled ? "已开启" : "未开启")")

        // 7. 弹窗 —— 这是最需要实证的一项
        out("[弹窗] 1.5 秒后弹出测试提醒…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            popup.showTest()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                out("[弹窗] \(popup.debugPanelInfo)")
                out("[弹窗] 队列里还剩 \(popup.debugQueueCount) 个")
                out(popup.isShowing ? "[弹窗] ✅ 窗口已显示" : "[弹窗] ❌ 窗口没显示")
            }
        }

        // 8. 记录文件
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            out("[记录] 今天已服用 \(log.takenCountToday()) 次，流水共 \(log.records.count) 条")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            out("===== 自检结束 =====")
            exit(0)
        }
    }
}
