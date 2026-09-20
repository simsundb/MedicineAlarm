import AppKit
import SwiftUI

/// 「设置」窗口。跟 MainWindowController 一样，手动把 SwiftUI 视图塞进 NSWindow——
/// 应用用 AppKit 传统方式启动，没有 SwiftUI 的 Scene 生命周期。
final class SettingsWindowController: NSWindowController {

    init(
        preferences: Preferences,
        store: AlarmStore,
        onPreviewChime: @escaping (String) -> Void
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 660),
            // 设置窗口不需要最小化 / 缩放，够用就好
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        let root = SettingsView(
            preferences: preferences,
            store: store,
            onPreviewChime: onPreviewChime,
            onClose: { [weak window] in window?.close() }
        )
        window.contentView = NSHostingView(rootView: root)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
