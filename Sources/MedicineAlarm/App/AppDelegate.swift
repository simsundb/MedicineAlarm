import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var store: AlarmStore!
    private var log: DoseLog!
    private var scheduler: Scheduler!
    private var popup: PopupController!
    private var statusBar: StatusBarController!
    private var mainWindow: MainWindowController!
    private var historyWindow: HistoryWindowController!
    private var settingsWindow: SettingsWindowController!

    private var refreshTimer: Timer?
    private var testObserver: NSObjectProtocol?
    /// 偏好一变就刷新菜单栏文字（比如刚勾上「周六免打扰」）
    private var preferencesObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 程序坞 + 菜单栏双入口：程序坞图标负责好找（点它调 applicationShouldHandleReopen
        // 把主窗口带出来），菜单栏图标负责一眼看到下一个闹钟。
        // 之前是 .accessory（纯菜单栏、无程序坞图标），但那样图标藏在菜单栏里不好找。
        NSApp.setActivationPolicy(.regular)

        // 装主菜单——主要是为了「编辑」菜单（文本框的 ⌘C/⌘V）
        // 和「设置…」的 ⌘, 快捷键。
        MainMenu.install(
            settingsTarget: self,
            settingsAction: #selector(showSettings(_:))
        )

        store = AlarmStore()
        log = DoseLog()
        scheduler = Scheduler(store: store, log: log)
        popup = PopupController(scheduler: scheduler)

        mainWindow = MainWindowController(
            store: store,
            log: log,
            scheduler: scheduler,
            onChanged: { [weak self] (changed: Alarm?) in
                // 闹钟刚被改动：把今天这个时间点标记为已处理，
                // 免得把时间改到今天已过去的时刻时立刻弹一个窗
                if let changed {
                    self?.scheduler.markHandledToday(changed)
                }
                self?.statusBar.refreshTitle()
            },
            onTest: { [weak self] in self?.popup.showTest() },
            // settingsWindow 在下面才创建，闭包捕获 self、调用时才读，所以顺序无所谓
            onSettings: { [weak self] in self?.settingsWindow.show() }
        )

        historyWindow = HistoryWindowController(log: log)

        settingsWindow = SettingsWindowController(
            preferences: .shared,
            store: store,
            onPreviewChime: { [weak self] name in self?.popup.previewChime(name) }
        )

        statusBar = StatusBarController(
            store: store,
            log: log,
            scheduler: scheduler,
            onShowMain: { [weak self] in self?.mainWindow.show() },
            onShowHistory: { [weak self] in self?.historyWindow.show() },
            onShowSettings: { [weak self] in self?.settingsWindow.show() },
            onQuit: { NSApp.terminate(nil) }
        )

        scheduler.onFire = { [weak self] fire in
            self?.popup.enqueue(fire)
        }
        popup.onStateChanged = { [weak self] in
            self?.statusBar.refreshTitle()
        }

        scheduler.start()

        // 菜单栏上的倒计时文字定期刷新
        let timer = Timer(timeInterval: 20, repeats: true) { [weak self] _ in
            self?.statusBar.refreshTitle()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        // 设置在设置窗口里一改，菜单栏立刻跟上，不用等下一次 20 秒的刷新
        preferencesObserver = Preferences.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.statusBar.refreshTitle() }

        testObserver = NotificationCenter.default.addObserver(
            forName: .medicineAlarmTest, object: nil, queue: .main
        ) { [weak self] _ in
            self?.popup.showTest()
        }

        confirmLegacyConfigImportIfNeeded()

        // 自检模式：跑一遍关键路径后自己退出，不打扰用户
        if CommandLine.arguments.contains("--self-test") {
            SelfTest.run(
                store: store,
                log: log,
                scheduler: scheduler,
                popup: popup
            )
            return
        }

        // 头一次运行就把主窗口打开，让用户确认应用确实装好了
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            mainWindow.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stop()
        refreshTimer?.invalidate()
        preferencesObserver?.cancel()
        if let testObserver {
            NotificationCenter.default.removeObserver(testObserver)
        }
    }

    /// 主菜单「设置…」（⌘,）的落点
    @objc private func showSettings(_ sender: Any?) {
        settingsWindow.show()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // 关掉所有窗口后应用继续留着（菜单栏还要靠它）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 点程序坞 / Finder / 「应用程序」文件夹里的图标时，把主窗口带出来。
    ///
    /// 窗口全关掉之后应用并不退出（菜单栏还要靠它），此时用户点图标，
    /// macOS 发来的就是这个 reopen 事件。不实现它，点图标就是「什么都没发生」——
    /// 看起来像应用没启动成功。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindow.show() }
        return true
    }

    /// 如果这次是首次运行、且成功导入了旧版 Python 程序的配置，跟用户说一声。
    private func confirmLegacyConfigImportIfNeeded() {
        let legacyURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".medicine_alarm/config.json")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        guard !UserDefaults.standard.bool(forKey: "didReportLegacyImport") else { return }
        UserDefaults.standard.set(true, forKey: "didReportLegacyImport")

        NSLog("[MedicineAlarm] 已从旧版配置导入 \(store.alarms.count) 个闹钟")
    }
}
