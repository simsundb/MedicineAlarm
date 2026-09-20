import SwiftUI
import AppKit

/// 「设置」窗口。
///
/// 内容分三块：提醒怎么响（声音 / 语音）、什么时候不响（免打扰 / 补服窗口）、
/// 以及启动和数据位置。每组都配一行说明——设置项光有标题，
/// 过两个月自己都不记得当初为什么这么勾。
struct SettingsView: View {

    @ObservedObject var preferences: Preferences
    @ObservedObject var store: AlarmStore
    let onPreviewChime: (String) -> Void
    let onClose: () -> Void

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?
    @State private var showingLoginItemError = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
        }
        .frame(width: 460, height: 640)
        .background(Color(nsColor: .underPageBackgroundColor))
        .alert(
            "无法修改开机自启",
            isPresented: $showingLoginItemError,
            presenting: loginItemError
        ) { _ in
            Button("好", role: .cancel) {}
        } message: { reason in
            Text(reason)
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: Theme.Space.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text("设置")
                    .font(.system(size: 18, weight: .semibold))
                Text("提醒方式、免打扰与启动行为")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("完成") { onClose() }
                .buttonStyle(PrimaryActionButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.lg)
        .background(Color.cardSurface)
    }

    // MARK: - 表单

    private var form: some View {
        Form {
            Section("提醒") {
                Toggle("语音播报", isOn: $preferences.speakEnabled)
                    .toggleStyle(.switch)
                caption("弹窗出现时用中文念一遍「该吃药了」和闹钟名称。")
            }

            Section("提示音") {
                LabeledContent("音效") {
                    HStack(spacing: Theme.Space.sm) {
                        Picker("", selection: $preferences.chimeName) {
                            ForEach(AlarmSound.availableChimes, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)

                        Button("试听") { onPreviewChime(preferences.chimeName) }
                            .help("立刻放一遍这个音效")
                    }
                }

                LabeledContent("间隔") {
                    Stepper(value: $preferences.chimeInterval, in: 2...30, step: 1) {
                        Text("每 \(Int(preferences.chimeInterval)) 秒响一次")
                            .monospacedDigit()
                    }
                }

                caption("提醒会一直响到你在弹窗上做选择为止。")
            }

            Section("免打扰") {
                HStack(spacing: Theme.Space.xs) {
                    ForEach(Preferences.weekdayOptions) { option in
                        weekdayChip(option)
                    }
                    Spacer(minLength: 0)
                }
                caption("选中的星期几完全不提醒，也不记「已错过」。适合周末或休息日不开电脑的时候——不选则每天都提醒。")
            }

            Section("补服") {
                LabeledContent("补服窗口") {
                    Picker("", selection: $preferences.catchUpWindowHours) {
                        ForEach(Preferences.catchUpOptions, id: \.self) { hours in
                            Text(Self.hoursText(hours)).tag(hours)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                caption("电脑睡醒或应用重开后，迟到超过这个时长的提醒只记一笔「已错过」，不再补弹——免得一开机被一堆过期弹窗淹没。")
            }

            Section("启动") {
                Toggle("开机自动启动", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, wanted in
                        applyLoginItem(wanted)
                    }
                caption(launchAtLogin
                    ? "已注册。也可以在「系统设置 › 通用 › 登录项」里查看。"
                    : "登录后自动在菜单栏常驻，不用每次手动打开。")
            }

            Section("数据") {
                LabeledContent("闹钟配置") {
                    HStack(spacing: Theme.Space.sm) {
                        Text("\(store.alarms.count) 个闹钟")
                            .foregroundStyle(.secondary)
                        Button("在访达中显示") { revealConfig() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    /// 小节说明文字。统一字号和颜色，免得每处各写一遍。
    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 免打扰日

    /// 一个星期几的小方块，点一下切换选中。比 7 个开关更省地方，
    /// 也更容易一眼看出「哪几天是安静的」。
    private func weekdayChip(_ option: Preferences.WeekdayOption) -> some View {
        let selected = preferences.skipWeekdays.contains(option.weekday)

        return Button {
            if selected {
                preferences.skipWeekdays.remove(option.weekday)
            } else {
                preferences.skipWeekdays.insert(option.weekday)
            }
        } label: {
            Text(option.label)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 40, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(selected ? Color.brand : Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(selected ? Color.brand : Color.cardBorder, lineWidth: 1)
        )
        .help(selected ? "已设为免打扰，点击取消" : "设为免打扰")
        .accessibilityLabel("跳过\(option.label)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - 动作

    private func applyLoginItem(_ wanted: Bool) {
        // 已经是这个状态就别再调一次——回滚赋值会再次触发 onChange，
        // 这个 guard 是让那条路径自然终止的地方。
        guard wanted != LoginItem.isEnabled else { return }

        if let error = LoginItem.setEnabled(wanted) {
            loginItemError = error
            showingLoginItemError = true
            launchAtLogin = LoginItem.isEnabled
        }
    }

    private func revealConfig() {
        let url = URL(fileURLWithPath: store.configPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func hoursText(_ hours: Double) -> String {
        if hours < 1 { return "\(Int(hours * 60)) 分钟" }
        return "\(Int(hours)) 小时"
    }
}
