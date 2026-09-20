import SwiftUI

/// 到点提醒弹窗。
///
/// 信息层级：先让人一眼看到「该吃药了」，再是几点、吃什么，
/// 最后才是「今天吃到第几次」——让用户在迷糊中也能立刻做决定。
struct PopupView: View {
    let fire: AlarmFire
    let takenToday: Int
    let totalToday: Int
    let onTaken: () -> Void
    let onSnooze: (Int) -> Void

    /// 补服时用琥珀色，正常到点用主色，推迟回来用青色。
    private var accent: Color {
        if fire.isLate { return .statusLate }
        if fire.isSnooze { return .statusSnoozed }
        return .brand
    }

    private var headline: String {
        fire.isLate ? "该补服了" : "该吃药了"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Space.lg)

            IconBadge(systemName: "pills.fill", size: 74, tint: accent)

            VStack(spacing: Theme.Space.xs + 2) {
                Text(headline)
                    .font(Theme.Typo.hero)
                    .foregroundStyle(.primary)

                HStack(spacing: Theme.Space.sm) {
                    Text(fire.alarm.timeString)
                        .font(Theme.Typo.clock)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(fire.alarm.label)
                        .font(Theme.Typo.heroSub)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, Theme.Space.lg)

            // 补服 / 推迟的说明。正常到点时不占位置。
            Group {
                if fire.isLate {
                    StatusChip(
                        icon: "clock.badge.exclamationmark.fill",
                        text: "补服提醒 · 原定 \(timeString(fire.scheduled))",
                        color: .statusLate,
                        softColor: .statusLateSoft
                    )
                } else if fire.isSnooze {
                    StatusChip(
                        icon: "clock.arrow.circlepath",
                        text: "稍后提醒 · 原定 \(timeString(fire.scheduled))",
                        color: .statusSnoozed,
                        softColor: .statusSnoozedSoft
                    )
                }
            }
            .padding(.top, Theme.Space.md)

            Spacer(minLength: Theme.Space.lg)

            progressRow
                .padding(.horizontal, Theme.Space.xl)

            HStack(spacing: Theme.Space.sm) {
                Button("已服用", action: onTaken)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .accessibilityHint("记录本次服药并关闭提醒")

                Button("稍后 5 分钟") { onSnooze(5) }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .keyboardShortcut(.cancelAction)

                Button("稍后 10 分钟") { onSnooze(10) }
                    .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(.top, Theme.Space.lg)

            Text("按 Enter 确认服用 · 按 Esc 稍后提醒")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, Theme.Space.md)
                .padding(.bottom, Theme.Space.lg)
        }
        .padding(.horizontal, Theme.Space.xl)
        .frame(width: 460, height: 350)
        .background(background)
    }

    /// 今天吃到第几次了——放在按钮上方，给一个「还差几次」的即时反馈。
    private var progressRow: some View {
        HStack(spacing: Theme.Space.md) {
            DoseProgressRing(taken: takenToday, total: totalToday, size: 36, lineWidth: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text("今天已服用 \(takenToday)/\(totalToday) 次")
                    .font(.system(size: 13, weight: .semibold))
                Text(remainingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.cardSurface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
    }

    private var remainingText: String {
        let remaining = max(0, totalToday - takenToday)
        if remaining == 0 { return "今天的药都吃完了" }
        return "还差 \(remaining) 次"
    }

    /// 半透明材质打底 + 顶部一层主色渐隐，跟系统弹窗的质感一致。
    private var background: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            LinearGradient(
                colors: [accent.opacity(0.14), accent.opacity(0.0)],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
