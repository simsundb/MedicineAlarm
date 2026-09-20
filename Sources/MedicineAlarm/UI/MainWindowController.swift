import AppKit
import SwiftUI

/// 「管理闹钟」主窗口。
///
/// 应用用 AppKit 传统方式启动（没有 SwiftUI 的 Scene 生命周期），
/// 所以手动把 SwiftUI 视图塞进一个 NSWindow 里，并由本类持有它。
final class MainWindowController: NSWindowController, NSWindowDelegate {

    private let store: AlarmStore
    private let log: DoseLog
    /// 只用来读「下一个闹钟」，不做改动
    private let scheduler: Scheduler
    /// 闹钟有变动时回调，带上被改动的那个（删除时传 nil）
    private let onChanged: (Alarm?) -> Void
    private let onTest: () -> Void
    /// 打开设置窗口
    private let onSettings: () -> Void

    init(
        store: AlarmStore,
        log: DoseLog,
        scheduler: Scheduler,
        onChanged: @escaping (Alarm?) -> Void,
        onTest: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) {
        self.store = store
        self.log = log
        self.scheduler = scheduler
        self.onChanged = onChanged
        self.onTest = onTest
        self.onSettings = onSettings

        // 高度 720 是量出来的，不是拍的：默认那 7 个闹钟分成早/中/晚三组，
        // 各组标题 + 卡片 + 间距 + 上下留白一共约 717pt。
        // 定在这个尺寸，出厂配置正好铺满且不出滚动条；闹钟再多才滚动——
        // 这正是「默认别滚、多了才滚」想要的效果。
        // 用户手动拖小窗口仍然会出滚动条，那是他们自己的选择。
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "吃药提醒"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 460)
        window.setFrameAutosaveName("MedicineAlarmMainWindow")

        super.init(window: window)

        window.delegate = self

        let root = AlarmListView(
            store: store,
            log: log,
            scheduler: scheduler,
            onChanged: onChanged,
            onTest: onTest,
            onSettings: onSettings
        )
        window.contentView = NSHostingView(rootView: root)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    /// 从程序坞 / 菜单栏 / 设置窗口打开主窗口。必须先激活自己，
    /// 否则窗口会出现在其他应用后面。
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
