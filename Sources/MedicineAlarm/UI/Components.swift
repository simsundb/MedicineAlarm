import SwiftUI

/// 服药状态 → 颜色 / 图标 / 文案 的统一映射。
///
/// 每个状态都同时用「图标 + 文字」表达，不单靠颜色区分（色觉障碍也能读）。
extension DoseRecord.Status {
    var color: Color {
        switch self {
        case .taken:   return .statusTaken
        case .snoozed: return .statusSnoozed
        case .missed:  return .statusLate
        }
    }

    var softColor: Color {
        switch self {
        case .taken:   return .statusTakenSoft
        case .snoozed: return .statusSnoozedSoft
        case .missed:  return .statusLateSoft
        }
    }
}

/// 小圆角标签：图标 + 文字 + 同色衬底。
struct StatusChip: View {
    let icon: String
    let text: String
    let color: Color
    var softColor: Color?

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.sm, weight: .semibold))
            Text(text)
                .font(Theme.Typo.chip)
        }
        .foregroundStyle(color)
        .padding(.horizontal, Theme.Space.sm + 2)
        .padding(.vertical, Theme.Space.xs + 1)
        .background(Capsule().fill(softColor ?? color.opacity(0.13)))
        .overlay(Capsule().strokeBorder(color.opacity(0.30), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

extension StatusChip {
    init(status: DoseRecord.Status) {
        self.init(
            icon: status.symbolName,
            text: status.displayName,
            color: status.color,
            softColor: status.softColor
        )
    }
}

/// 今日服药进度环。数字 + 环形，进度一眼可见。
struct DoseProgressRing: View {
    let taken: Int
    let total: Int
    var size: CGFloat = 46
    var lineWidth: CGFloat = 5

    private var fraction: Double {
        total > 0 ? min(1, Double(taken) / Double(total)) : 0
    }

    private var isComplete: Bool { total > 0 && taken >= total }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cardBorder, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    isComplete ? Color.statusTaken : Color.brand,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Motion.animation(.easeOut(duration: 0.45)), value: fraction)

            VStack(spacing: -1) {
                Text("\(taken)")
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("/\(total)")
                    .font(.system(size: size * 0.20, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今天已服用 \(taken) 次，共 \(total) 次")
    }
}

/// 圆底图标——弹窗和空状态都用它，保证视觉语言一致。
struct IconBadge: View {
    let systemName: String
    var size: CGFloat = 72
    var tint: Color = .brand

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
            Circle()
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
            Image(systemName: systemName)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)   // 旁边的文字已经说明了含义
    }
}
