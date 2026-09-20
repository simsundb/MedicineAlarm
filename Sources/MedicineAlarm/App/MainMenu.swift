import AppKit

/// 应用主菜单栏。
///
/// 这个应用之前完全没有主菜单——但主菜单不只是好看：
/// 没有「编辑」菜单，SwiftUI 里的文本框连 ⌘V 都不能用（新增闹钟的名称输入框就一直如此）。
/// 这里补一份最小可用的菜单，并挂上「设置…」的 ⌘, 这个 macOS 通用快捷键。
enum MainMenu {

    private static let appName = "吃药提醒"

    /// 装好主菜单。`settingsTarget` / `settingsAction` 指向应用自己实现的
    /// 「打开设置窗口」方法——不用 SwiftUI 的 Settings scene，因为这里没有 Scene 生命周期。
    static func install(settingsTarget: AnyObject, settingsAction: Selector) {
        let mainMenu = NSMenu()

        mainMenu.addItem(appMenuItem(target: settingsTarget, action: settingsAction))
        mainMenu.addItem(submenuItem(editMenu()))
        mainMenu.addItem(submenuItem(windowMenu()))

        NSApp.mainMenu = mainMenu
    }

    // MARK: - 各菜单

    private static func appMenuItem(target: AnyObject, action: Selector) -> NSMenuItem {
        let menu = NSMenu(title: appName)

        menu.addItem(
            withTitle: "关于\(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: action, keyEquivalent: ",")
        settings.target = target
        menu.addItem(settings)

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "隐藏\(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let hideOthers = NSMenuItem(
            title: "隐藏其他",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(
            withTitle: "全部显示",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "退出\(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        return submenuItem(menu)
    }

    /// 标准编辑菜单。target 留空，靠响应者链找到当前的第一响应者
    /// （也就是正在编辑的那个文本框）。
    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "编辑")

        menu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)

        menu.addItem(.separator())

        menu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "窗口")

        menu.addItem(
            withTitle: "最小化",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        menu.addItem(
            withTitle: "缩放",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "关闭窗口",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "前置全部窗口",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )

        return menu
    }

    private static func submenuItem(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
