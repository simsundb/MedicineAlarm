import AppKit

// 命令行小工具：不启动界面，直接开关开机自启 / 查询状态。
// 主要用途是安装后验证「开机自启到底注册成功没有」。
// 用法见 build_app.sh 末尾的提示。
let arguments = CommandLine.arguments

if arguments.contains("--set-login-item") {
    let enable = arguments.contains("on")
    if let error = LoginItem.setEnabled(enable) {
        FileHandle.standardError.write("设置失败: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
    print(enable ? "开机自启已开启" : "开机自启已关闭")
    exit(0)
}

if arguments.contains("--login-item-status") {
    print(LoginItem.isEnabled ? "开机自启: 已开启" : "开机自启: 未开启")
    print("SMAppService 状态: \(LoginItem.smAppServiceStatusDescription)")
    print("LaunchAgent 回退文件: \(FileManager.default.fileExists(atPath: LoginItem.agentURL.path) ? "存在" : "不存在")")
    exit(0)
}

// 这是个「程序坞 + 菜单栏」双入口的常驻应用：
// 程序坞图标负责好找，菜单栏图标负责一眼看到下一个闹钟。
// 没有 SwiftUI 的 Scene 生命周期，用 AppKit 的传统方式启动，窗口全部由 AppDelegate 手动管理。
//
// 放在 main.swift 里用顶层代码，SPM 会把它当作可执行入口，
// 不需要 @main / -parse-as-library。

let application = NSApplication.shared

let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
