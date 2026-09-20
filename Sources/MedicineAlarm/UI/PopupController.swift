import AppKit
import SwiftUI

/// 提醒弹窗用的面板。
///
/// 与普通窗口的区别：
/// - 可以成为 key window（这样才能接收按钮点击和 Enter / Esc 快捷键）
/// - 层级压在所有普通窗口之上
/// - 出现在用户当前所在的那个「桌面/空间」，也能盖在全屏应用上
final class AlarmPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Esc 等同于「稍后 5 分钟」，给一个不会误事又随时能脱身的出口。
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Esc
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    var onEscape: (() -> Void)?
}

/// 负责按队列逐个弹出提醒窗口。
///
/// 多个闹钟同时到点（例如电脑睡醒后补服）时不会叠一堆窗口，
/// 而是弹一个、关掉一个、再弹下一个。
final class PopupController {

    private let scheduler: Scheduler
    private var panel: AlarmPanel?
    private var queue: [AlarmFire] = []
    private var current: AlarmFire?
    private let sound = AlarmSound()

    /// 提醒状态发生变化时回调，让菜单栏刷新。
    var onStateChanged: (() -> Void)?

    init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }

    // MARK: - 队列

    /// 试听提示音（设置窗口用）。
    func previewChime(_ name: String) {
        sound.preview(name)
    }

    func enqueue(_ fire: AlarmFire) {
        queue.append(fire)
        if current == nil { showNext() }
    }

    /// 立即弹一个测试提醒，用来验证声音、置顶、按钮是否正常。
    func showTest() {
        let alarm = Alarm(hour: Calendar.current.component(.hour, from: Date()),
                          minute: Calendar.current.component(.minute, from: Date()),
                          label: "测试提醒")
        enqueue(AlarmFire(alarm: alarm, scheduled: Date(), fireAt: Date(), isSnooze: false))
    }

    private func showNext() {
        guard !queue.isEmpty else {
            current = nil
            teardownPanel()
            onStateChanged?()
            return
        }
        let fire = queue.removeFirst()
        current = fire
        present(fire)
        onStateChanged?()
    }

    // MARK: - 窗口

    private func present(_ fire: AlarmFire) {
        teardownPanel()

        let panel = AlarmPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 350),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .alertPanel
        panel.isFloatingPanel = true
        // 让 SwiftUI 里的材质背景自己画出圆角，窗口本身不铺底色
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // 压过普通窗口和全屏应用：
        // - .screenSaver(1000) 高于 floating/statusBar，能盖住全屏内容
        // - .canJoinAllSpaces 跟随用户当前所在的桌面
        // - .canJoinAllApplications 才能盖在「别的应用」的全屏空间上
        // - .fullScreenAuxiliary 允许与全屏窗口共存
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllApplications,
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
        ]

        // 没有关闭按钮：必须点「已服用」或「稍后提醒」才能走
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let progress = scheduler.todayProgress()
        let view = PopupView(
            fire: fire,
            takenToday: progress.taken,
            totalToday: progress.total,
            onTaken: { [weak self] in self?.handleTaken(fire) },
            onSnooze: { [weak self] minutes in self?.handleSnooze(fire, minutes: minutes) }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = hosting
        panel.setContentSize(NSSize(width: 460, height: 350))

        panel.onEscape = { [weak self] in self?.handleSnooze(fire, minutes: 5) }

        // 居中到鼠标所在的那块屏幕，而不是主屏——用户在看哪块屏就在哪弹
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        if let screen {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            )
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }

        self.panel = panel

        // .nonactivatingPanel + makeKeyAndOrderFront：窗口能拿到按键焦点（Enter / Esc 可用），
        // 但不会把用户从他正在用的应用里硬拽出来。
        // orderFrontRegardless 再兜一层，确保一定冒到最前面。
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        sound.start(
            text: "该吃药了，\(fire.alarm.label)",
            speak: Preferences.shared.speakEnabled
        )
    }

    private func teardownPanel() {
        sound.stop()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    // MARK: - 用户动作

    private func handleTaken(_ fire: AlarmFire) {
        scheduler.confirmTaken(fire)
        dismissCurrent()
    }

    private func handleSnooze(_ fire: AlarmFire, minutes: Int) {
        scheduler.snooze(fire, minutes: minutes)
        dismissCurrent()
    }

    private func dismissCurrent() {
        current = nil
        teardownPanel()
        // 稍等一下再弹下一个，避免闪现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.showNext()
        }
    }

    /// 有没有正在显示的提醒
    var isShowing: Bool { panel != nil }

    /// 供 `--self-test` 打印的诊断信息
    var debugPanelInfo: String {
        guard let panel else { return "没有窗口（弹窗未创建）" }
        return """
        visible=\(panel.isVisible) key=\(panel.isKeyWindow) \
        level=\(panel.level.rawValue) \
        frame=\(Int(panel.frame.width))x\(Int(panel.frame.height)) \
        origin=(\(Int(panel.frame.origin.x)),\(Int(panel.frame.origin.y))) \
        screens=\(NSScreen.screens.count)
        """
    }

    var debugQueueCount: Int { queue.count }
}
