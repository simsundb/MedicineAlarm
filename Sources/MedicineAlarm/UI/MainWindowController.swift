import AppKit
import SwiftUI

/// 「管理闹钟」主窗口。
///
/// 这是个菜单栏（LSUIElement）应用，没有 SwiftUI 的 Scene 生命周期，
/// 所以手动把 SwiftUI 视图塞进一个 NSWindow 里，并由本类持有它。
final class MainWindowController: NSWindowController, NSWindowDelegate {

    private let store: AlarmStore
    private let log: DoseLog
    /// 只用来读「下一个闹钟」，不做改动
    private let scheduler: Scheduler
    /// 闹钟有变动时回调，带上被改动的那个（删除时传 nil）
    private let onChanged: (Alarm?) -> Void
    private let onTest: () -> Void

    init(
        store: AlarmStore,
        log: DoseLog,
        scheduler: Scheduler,
        onChanged: @escaping (Alarm?) -> Void,
        onTest: @escaping () -> Void
    ) {
        self.store = store
        self.log = log
        self.scheduler = scheduler
        self.onChanged = onChanged
        self.onTest = onTest

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
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
            onTest: onTest
        )
        window.contentView = NSHostingView(rootView: root)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    /// 从菜单栏打开窗口。作为 accessory 应用必须先激活自己，
    /// 否则窗口会出现在其他应用后面。
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
