import Foundation
import ServiceManagement

/// 开机自启的注册 / 注销。
///
/// 优先用 macOS 13+ 的 `SMAppService`（标准的「登录项」，
/// 会出现在 系统设置 › 通用 › 登录项 里）。如果因为签名方式
/// （本应用是 ad-hoc 签名，没有 Developer ID）被系统拒绝，
/// 就退回到写一个用户级 LaunchAgent。
enum LoginItem {

    static let agentLabel = "com.sunzh.medicine-alarm"

    static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    static var isEnabled: Bool {
        if SMAppService.mainApp.status == .enabled { return true }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    /// 给 `--login-item-status` 用的可读状态
    static var smAppServiceStatusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered:   return "未注册"
        case .enabled:         return "已启用"
        case .requiresApproval: return "等待用户在系统设置里批准"
        case .notFound:        return "找不到应用（可能没通过 LaunchServices 启动过）"
        @unknown default:      return "未知(\(SMAppService.mainApp.status.rawValue))"
        }
    }

    /// 返回 nil 表示成功；否则是给用户看的失败原因。
    @discardableResult
    static func setEnabled(_ on: Bool) -> String? {
        on ? enable() : disable()
    }

    // MARK: - 开启

    private static func enable() -> String? {
        var smError: String?

        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
            if SMAppService.mainApp.status == .enabled {
                removeAgent()   // 确保不会两条路径同时生效
                return nil
            }
            smError = "SMAppService 状态为 \(SMAppService.mainApp.status.rawValue)"
        } catch {
            smError = error.localizedDescription
        }

        NSLog("[MedicineAlarm] SMAppService 注册失败（%@），回退到 LaunchAgent", smError ?? "未知原因")

        if let agentError = writeAgent() {
            return "开机自启设置失败：\(agentError)"
        }
        return nil
    }

    // MARK: - 关闭

    private static func disable() -> String? {
        var failures: [String] = []

        if SMAppService.mainApp.status == .enabled {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        if let agentError = removeAgent() {
            failures.append(agentError)
        }

        return failures.isEmpty ? nil : "关闭开机自启时出错：\(failures.joined(separator: "；"))"
    }

    // MARK: - LaunchAgent 回退方案

    private static func writeAgent() -> String? {
        guard let executable = Bundle.main.executableURL else {
            return "无法定位应用路径"
        }

        // 用 `open` 而不是直接指向可执行文件：走 LaunchServices 启动，
        // 应用的 bundle 信息、通知权限、窗口激活行为才和手动双击一致。
        let appPath = Bundle.main.bundleURL.path
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", appPath],
            "RunAtLoad": true,
            "KeepAlive": false,
            // 告诉 launchd 这是个交互式 GUI 应用，别对它做 App Nap
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]

        do {
            try FileManager.default.createDirectory(
                at: agentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0
            )
            try data.write(to: agentURL, options: .atomic)
        } catch {
            return error.localizedDescription
        }

        // 让 launchd 立刻加载这份 plist
        _ = runLaunchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
        _ = executable   // 保留引用，方便将来切换成直接启动可执行文件
        return nil
    }

    @discardableResult
    private static func removeAgent() -> String? {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return nil }
        _ = runLaunchctl(["bootout", "gui/\(getuid())/\(agentLabel)"])
        do {
            try FileManager.default.removeItem(at: agentURL)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
