import AppKit

/// 菜单栏图标 + 下拉菜单。
///
/// 菜单内容每次展开时（`menuNeedsUpdate`）重新构建，
/// 这样「下一个闹钟还有多久」「今天吃了几次」永远是最新的。
final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let store: AlarmStore
    private let log: DoseLog
    private let scheduler: Scheduler
    private let onShowMain: () -> Void
    private let onShowHistory: () -> Void
    private let onShowSettings: () -> Void
    private let onQuit: () -> Void

    init(
        store: AlarmStore,
        log: DoseLog,
        scheduler: Scheduler,
        onShowMain: @escaping () -> Void,
        onShowHistory: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.store = store
        self.log = log
        self.scheduler = scheduler
        self.onShowMain = onShowMain
        self.onShowHistory = onShowHistory
        self.onShowSettings = onShowSettings
        self.onQuit = onQuit

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "pills.fill",
                accessibilityDescription: "吃药提醒"
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.toolTip = "吃药提醒"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        refreshTitle()
    }

    // MARK: - 图标上的文字

    /// 图标旁边显示下一个闹钟时间；暂停或免打扰日显示对应状态。
    func refreshTitle() {
        guard let button = statusItem.button else { return }

        if scheduler.isPaused {
            button.title = " 暂停"
            button.toolTip = "提醒已暂停"
            return
        }

        if Preferences.shared.isSkipToday {
            button.title = " 免打扰"
            button.toolTip = "今天是免打扰日，不会提醒"
            return
        }

        guard let next = scheduler.nextFire() else {
            button.title = ""
            button.toolTip = "没有启用中的闹钟"
            return
        }

        button.title = " \(next.alarm.timeString)"
        button.toolTip = "下一个闹钟：\(next.alarm.timeString) \(next.alarm.label)"
    }

    // MARK: - 菜单

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // 下一个闹钟
        if Preferences.shared.isSkipToday {
            menu.addItem(info("今天是免打扰日，不提醒也不记账"))
        } else if let next = scheduler.nextFire() {
            menu.addItem(info("下一个：\(next.alarm.timeString) \(next.alarm.label)"))
            menu.addItem(info("           \(relativeTime(to: next.date))"))
        } else {
            menu.addItem(info("没有启用中的闹钟"))
        }

        // 免打扰日没有「今天吃了几次」可言，不占位置
        if !Preferences.shared.isSkipToday {
            let taken = log.takenCountToday()
            let total = store.enabledCount
            menu.addItem(info("今天已服用 \(taken)/\(total) 次"))
        }

        if let pausedUntil = scheduler.pausedUntilDate {
            menu.addItem(info("提醒暂停至 \(timeString(pausedUntil))"))
        }

        menu.addItem(.separator())

        menu.addItem(action("管理闹钟…", #selector(showMain)))
        menu.addItem(action("服药记录…", #selector(showHistory), key: "r"))
        menu.addItem(action("设置…", #selector(showSettings), key: ","))

        menu.addItem(.separator())

        // 暂停提醒
        let pauseItem = NSMenuItem(title: "暂停提醒", action: nil, keyEquivalent: "")
        let pauseMenu = NSMenu()
        if scheduler.isPaused {
            pauseMenu.addItem(action("恢复提醒", #selector(resumeAlarms)))
        } else {
            pauseMenu.addItem(action("暂停 1 小时", #selector(pauseOneHour)))
            pauseMenu.addItem(action("暂停 4 小时", #selector(pauseFourHours)))
            pauseMenu.addItem(action("暂停到今天结束", #selector(pauseToday)))
        }
        pauseItem.submenu = pauseMenu
        menu.addItem(pauseItem)

        let speakItem = action("语音播报", #selector(toggleSpeak))
        speakItem.state = Preferences.shared.speakEnabled ? .on : .off
        menu.addItem(speakItem)

        let loginItem = action("开机自动启动", #selector(toggleLoginItem))
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        menu.addItem(action("立即测试弹窗", #selector(testPopup)))
        menu.addItem(.separator())
        menu.addItem(action("退出", #selector(quit), key: "q"))
    }

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - 动作

    @objc private func showMain() { onShowMain() }
    @objc private func showHistory() { onShowHistory() }
    @objc private func showSettings() { onShowSettings() }
    @objc private func testPopup() { NotificationCenter.default.post(name: .medicineAlarmTest, object: nil) }
    @objc private func quit() { onQuit() }

    @objc private func pauseOneHour() { scheduler.pause(for: 3600); didChange() }
    @objc private func pauseFourHours() { scheduler.pause(for: 4 * 3600); didChange() }
    @objc private func pauseToday() { scheduler.pauseUntilEndOfDay(); didChange() }
    @objc private func resumeAlarms() { scheduler.resume(); didChange() }

    @objc private func toggleSpeak() {
        Preferences.shared.speakEnabled.toggle()
    }

    @objc private func toggleLoginItem() {
        let target = !LoginItem.isEnabled
        if let error = LoginItem.setEnabled(target) {
            let alert = NSAlert()
            alert.messageText = target ? "无法开启开机自启" : "无法关闭开机自启"
            alert.informativeText = error
            alert.alertStyle = .warning
            alert.addButton(withTitle: "好")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        refreshTitle()
    }

    private func didChange() {
        refreshTitle()
    }

    // MARK: - 文案辅助

    private func relativeTime(to date: Date) -> String {
        let seconds = Int(date.timeIntervalSinceNow)
        if seconds < 60 { return "即将提醒" }
        let minutes = seconds / 60
        if minutes < 60 { return "还有 \(minutes) 分钟" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 { return "还有 \(hours) 小时" }
        return "还有 \(hours) 小时 \(remainder) 分钟"
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

extension Notification.Name {
    /// 从菜单触发一次测试弹窗
    static let medicineAlarmTest = Notification.Name("MedicineAlarmTestPopup")
}
