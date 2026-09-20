import SwiftUI

/// 「管理闹钟」窗口。
struct AlarmListView: View {
    @ObservedObject var store: AlarmStore
    @ObservedObject var log: DoseLog
    let scheduler: Scheduler
    /// 闹钟有变动时回调，带上被改动的那个（删除时传 nil）
    let onChanged: (Alarm?) -> Void
    let onTest: () -> Void
    /// 打开设置窗口（跟菜单栏那个「设置…」是同一个）
    let onSettings: () -> Void

    @State private var editing: Alarm?
    @State private var isAdding = false
    @State private var showingHistory = false
    /// 每 30 秒让视图重算一次「下一个闹钟」的高亮
    @State private var clockTick = Date()

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 500, minHeight: 560)
        .onReceive(ticker) { clockTick = $0 }
        .sheet(item: $editing) { alarm in
            AlarmEditView(
                title: "编辑闹钟",
                initial: alarm,
                onCancel: { editing = nil },
                onSave: { updated in
                    store.update(updated)
                    editing = nil
                    onChanged(updated)
                }
            )
        }
        .sheet(isPresented: $isAdding) {
            AlarmEditView(
                title: "新增闹钟",
                initial: Alarm(hour: 8, minute: 0, label: "服药"),
                onCancel: { isAdding = false },
                onSave: { alarm in
                    store.add(hour: alarm.hour, minute: alarm.minute, label: alarm.label)
                    isAdding = false
                    onChanged(alarm)
                }
            )
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(log: log, onClose: { showingHistory = false })
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: Theme.Space.lg) {
            DoseProgressRing(
                taken: log.takenCountToday(),
                total: store.enabledCount,
                size: 48
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("吃药提醒")
                    .font(.system(size: 18, weight: .semibold))
                Text(nextDoseSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Theme.Space.md)

            HStack(spacing: Theme.Space.sm) {
                Button {
                    showingHistory = true
                } label: {
                    Label("服药记录", systemImage: "list.bullet.rectangle")
                }
                .help("查看每天的服药流水")

                Button {
                    onTest()
                } label: {
                    Label("测试弹窗", systemImage: "bell.badge")
                }
                .help("立刻弹一次提醒，用来确认声音和置顶窗口是否正常")
            }

            Button {
                isAdding = true
            } label: {
                Label("新增", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .help("新增一个每日闹钟")

            // 齿轮收在最后，且只留图标：主操作「新增」该占最右的位置，
            // 而标题栏横向空间紧张，带文字的第四个按钮会把标题挤没。
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: Theme.IconSize.md, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("打开设置（也可以按 ⌘,）")
            .accessibilityLabel("设置")
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.vertical, Theme.Space.lg)
    }

    private var nextDoseSummary: String {
        if Preferences.shared.isSkipToday {
            return "今天是免打扰日，不提醒也不记账"
        }
        guard let next = scheduler.nextFire() else {
            return store.alarms.isEmpty ? "还没有设置闹钟" : "没有启用中的闹钟"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let minutes = Int(next.date.timeIntervalSinceNow) / 60
        let when = minutes < 1 ? "马上" : (minutes < 60 ? "\(minutes) 分钟后" : "\(minutes / 60) 小时后")
        return "下一个 \(next.alarm.timeString) \(next.alarm.label) · \(when)"
    }

    // MARK: - 列表

    private var content: some View {
        Group {
            if store.alarms.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.sm) {
                        ForEach(TimeBucket.allCases, id: \.self) { bucket in
                            let alarms = store.alarms.filter { bucket.contains($0) }
                            if !alarms.isEmpty {
                                sectionHeader(bucket)
                                ForEach(alarms) { alarm in
                                    AlarmCard(
                                        alarm: alarm,
                                        status: TodayStatus.status(for: alarm, log: log),
                                        isNext: nextAlarmID == alarm.id,
                                        onToggle: { enabled in
                                            store.setEnabled(enabled, for: alarm.id)
                                            onChanged(nil)
                                        },
                                        onEdit: { editing = alarm },
                                        onDelete: {
                                            store.delete(id: alarm.id)
                                            onChanged(nil)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.lg)
                }
                .background(Color(nsColor: .underPageBackgroundColor))
            }
        }
    }

    private var nextAlarmID: UUID? {
        // 读一下 clockTick，保证定时重算
        _ = clockTick
        return scheduler.nextFire()?.alarm.id
    }

    private func sectionHeader(_ bucket: TimeBucket) -> some View {
        Text(bucket.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, Theme.Space.sm)
            .padding(.leading, Theme.Space.xs)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.md) {
            IconBadge(systemName: "pills", size: 64)
            Text("还没有闹钟")
                .font(.system(size: 14, weight: .medium))
            Text("新增一个，到点会弹窗提醒你吃药")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("新增闹钟") { isAdding = true }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.top, Theme.Space.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

// MARK: - 时段分组

/// 按早/午/晚给闹钟分组，扫一眼就知道一天怎么排的。
enum TimeBucket: CaseIterable {
    case morning, afternoon, evening

    var title: String {
        switch self {
        case .morning:   return "早上"
        case .afternoon: return "下午"
        case .evening:   return "晚上"
        }
    }

    func contains(_ alarm: Alarm) -> Bool {
        switch self {
        case .morning:   return alarm.hour < 12
        case .afternoon: return (12..<18).contains(alarm.hour)
        case .evening:   return alarm.hour >= 18
        }
    }
}

// MARK: - 单个闹钟卡片

private struct AlarmCard: View {
    let alarm: Alarm
    let status: DoseRecord.Status?
    let isNext: Bool
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Text(alarm.timeString)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(alarm.enabled ? Color.primary : Color.secondary)
                .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(alarm.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(alarm.enabled ? Color.primary : Color.secondary)
                    .strikethrough(!alarm.enabled, color: .secondary)

                if let status {
                    StatusChip(status: status)
                } else if isNext && alarm.enabled {
                    StatusChip(icon: "arrow.right.circle.fill", text: "下一个", color: .brand)
                }
            }

            Spacer(minLength: Theme.Space.sm)

            // 悬停才出现的次要操作；删除是不可逆动作，保持显式
            if hovering {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: Theme.IconSize.md, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.brand)
                .help("编辑这个闹钟")
                .accessibilityLabel("编辑 \(alarm.timeString) \(alarm.label)")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: Theme.IconSize.md, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.danger)
                .help("删除这个闹钟")
                .accessibilityLabel("删除 \(alarm.timeString) \(alarm.label)")
            }

            Toggle("", isOn: Binding(get: { alarm.enabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel("启用 \(alarm.timeString) \(alarm.label)")
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(
                    isNext && alarm.enabled ? Color.brand.opacity(0.45) : Color.cardBorder,
                    lineWidth: isNext && alarm.enabled ? 1.5 : 1
                )
        )
        .opacity(alarm.enabled ? 1 : 0.62)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("编辑…") { onEdit() }
            Button("删除", role: .destructive) { onDelete() }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 今日状态

enum TodayStatus {
    /// 今天这个闹钟被怎么处理过；没记录就返回 nil。
    static func status(for alarm: Alarm, log: DoseLog) -> DoseRecord.Status? {
        log.todayRecords()
            .filter { $0.alarmID == alarm.id }
            .last?
            .status
    }
}
