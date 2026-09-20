import AppKit
import SwiftUI

/// 「服药记录」窗口。
final class HistoryWindowController: NSWindowController {

    private let log: DoseLog

    init(log: DoseLog) {
        self.log = log

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "服药记录"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 320)

        super.init(window: window)

        let root = HistoryView(log: log, onClose: { [weak window] in window?.close() })
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
