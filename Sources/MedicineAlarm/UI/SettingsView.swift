import SwiftUI
import AppKit

/// 「设置」窗口。
///
/// 排版语言刻意跟主窗口 / 服药记录保持一致：同样是「卡片 + 页背景」，
/// 而不是 macOS 原生的 `Form(.grouped)`——那套是「系统设置」的长相，
/// 放在这个应用里会跟其他三个窗口格格不入。
///
/// 每个分区的结构统一为：图标 + 标题 → 若干设置行 → 一行灰色说明。
/// 说明不是装饰：设置项光有标题，过两个月自己都不记得当初为什么这么勾。
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
            content
        }
        .frame(width: 480, height: 660)
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

    // MARK: - 顶部（跟主窗口同一套规格）

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

    // MARK: - 内容

    private var content: some View {
        ScrollView {
            VStack(spacing: Theme.Space.md) {
                reminderCard
                soundCard
                quietCard
                catchUpCard
                launchCard
                dataCard
            }
            .padding(Theme.Space.lg)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var reminderCard: some View {
        card(icon: "bell.badge.fill", title: "提醒", tint: .brand) {
            toggleRow("语音播报", isOn: $preferences.speakEnabled)
            note("弹窗出现时用中文念一遍「该吃药了」和闹钟名称。")
        }
    }

    private var soundCard: some View {
        card(icon: "speaker.wave.2.fill", title: "提示音", tint: .statusSnoozed) {
            HStack(spacing: Theme.Space.sm) {
                rowLabel("音效")
                Spacer(minLength: Theme.Space.sm)

                Picker("音效", selection: $preferences.chimeName) {
                    ForEach(AlarmSound.availableChimes, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(width: 116)

                Button("试听") { onPreviewChime(preferences.chimeName) }
                    .buttonStyle(InlineActionButtonStyle())
                    .help("立刻放一遍这个音效")
            }

            HStack(spacing: Theme.Space.sm) {
                rowLabel("间隔")
                Spacer(minLength: Theme.Space.sm)

                Text("每 \(Int(preferences.chimeInterval)) 秒响一次")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Stepper(
                    "间隔",
                    value: $preferences.chimeInterval,
                    in: 2...30,
                    step: 1
                )
                .labelsHidden()
            }

            note("提醒会一直响到你在弹窗上做选择为止。")
        }
    }

    private var quietCard: some View {
        card(icon: "moon.zzz.fill", title: "免打扰日", tint: .statusLate) {
            HStack(spacing: Theme.Space.xs) {
                ForEach(Preferences.weekdayOptions) { option in
                    weekdayChip(option)
                }
                Spacer(minLength: 0)
            }

            note("选中的星期几完全不提醒，也不记「已错过」。适合周末或休息日不开电脑的时候——一个都不选则每天都提醒。")
        }
    }

    private var catchUpCard: some View {
        card(icon: "clock.arrow.circlepath", title: "补服", tint: .statusTaken) {
            HStack(spacing: Theme.Space.sm) {
                rowLabel("补服窗口")
                Spacer(minLength: Theme.Space.sm)

                Picker("补服窗口", selection: $preferences.catchUpWindowHours) {
                    ForEach(Preferences.catchUpOptions, id: \.self) { hours in
                        Text(Self.hoursText(hours)).tag(hours)
                    }
                }
                .labelsHidden()
                .frame(width: 116)
            }

            note("电脑睡醒或应用重开后，迟到超过这个时长的提醒只记一笔「已错过」，不再补弹——免得一开机被一堆过期弹窗淹没。")
        }
    }

    private var launchCard: some View {
        card(icon: "power", title: "启动", tint: .brand) {
            toggleRow("开机自动启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, wanted in
                    applyLoginItem(wanted)
                }

            note(launchAtLogin
                ? "已注册。也可以在「系统设置 › 通用 › 登录项」里查看。"
                : "登录后自动在菜单栏常驻，不用每次手动打开。")
        }
    }

    private var dataCard: some View {
        card(icon: "folder", title: "数据", tint: .brand) {
            HStack(spacing: Theme.Space.sm) {
                rowLabel("闹钟配置")
                Spacer(minLength: Theme.Space.sm)

                Text("\(store.alarms.count) 个闹钟")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Button("在访达中显示") { revealConfig() }
                    .buttonStyle(InlineActionButtonStyle())
                    .help("打开闹钟配置文件所在的文件夹")
            }
        }
    }

    // MARK: - 复用零件

    /// 一张分区卡片。外观跟主窗口的闹钟卡片同一套（圆角、描边、底色）。
    private func card<Content: View>(
        icon: String,
        title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: icon)
                    .font(.system(size: Theme.IconSize.md, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(Theme.Typo.sectionTitle)
                Spacer(minLength: 0)
            }

            content()
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
    }

    /// 设置行左侧的标题文字。
    private func rowLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13))
    }

    /// 行内小按钮：文字 + 主色，无边框。跟「新增闹钟」里的快捷填入是同一套写法。
    private struct InlineActionButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.brand)
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, Theme.Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Color.brand.opacity(configuration.isPressed ? 0.20 : 0.10))
                )
                .contentShape(Rectangle())
        }
    }

    /// 开关行：左标题、右开关，跟主窗口闹钟卡片里的开关规格一致。
    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Space.sm) {
            rowLabel(title)
            Spacer(minLength: Theme.Space.sm)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(title)
        }
    }

    /// 小节说明。统一字号颜色，免得每处各写一遍。
    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 一个星期几的方块，点一下切换。比 7 个开关更省地方，
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
                .frame(width: 42, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                // 未选中时用页面底色做「凹陷」效果——卡片本身是 cardSurface，
                // 同色填充会让方块糊在卡片里看不出边界。
                .fill(selected ? Color.brand : Color(nsColor: .underPageBackgroundColor))
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
