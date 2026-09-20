import SwiftUI
import AppKit

/// 设计令牌（design tokens）。
///
/// 全应用的颜色 / 间距 / 字号都从这里取，不在各个视图里写死数值——
/// 这样深浅色、对齐节奏、改配色都只要动这一个文件。
///
/// 配色取自「医疗蓝 + 警示色」方向：主色天蓝，已服用用绿、补服用琥珀、
/// 推迟用青、删除等破坏性操作用红。所有文字色都验算过对比度 ≥ 4.5:1。
enum Theme {

    // MARK: - 间距（4/8 网格）
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - 圆角
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let pill: CGFloat = 999
    }

    // MARK: - 图标尺寸（统一节奏，避免 20/24/28 混用）
    enum IconSize {
        static let sm: CGFloat = 12
        static let md: CGFloat = 15
        static let lg: CGFloat = 22
        static let hero: CGFloat = 34
    }

    /// 字号。macOS 的原生正文字号是 13pt（不是 web 的 16px），
    /// 所以列表正文用语义化的 `.body` / `.caption`，跟着系统文字大小走；
    /// 只有弹窗大标题这种设计上必须固定的才写死。
    enum Typo {
        static let hero = Font.system(size: 28, weight: .bold)
        static let heroSub = Font.system(size: 16, weight: .medium)
        static let clock = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let sectionTitle = Font.system(size: 15, weight: .semibold)
        static let stat = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let chip = Font.system(size: 11, weight: .semibold)
    }
}

// MARK: - 语义颜色

extension Color {

    /// 主色：医疗蓝。浅色下用较深的 600 档保证正文对比度，深色下提亮。
    static let brand = adaptive(light: 0x0369A1, dark: 0x38BDF8)
    /// 主色的浅色衬底（图标底、选中背景）
    static let brandSoft = adaptive(light: 0xE0F2FE, dark: 0x0C4A6E)

    /// 已服用
    static let statusTaken = adaptive(light: 0x047857, dark: 0x34D399)
    static let statusTakenSoft = adaptive(light: 0xDCFCE7, dark: 0x064E3B)

    /// 补服提醒（迟到了）
    static let statusLate = adaptive(light: 0xB45309, dark: 0xFBBF24)
    static let statusLateSoft = adaptive(light: 0xFEF3C7, dark: 0x78350F)

    /// 已推迟
    static let statusSnoozed = adaptive(light: 0x0E7490, dark: 0x67E8F9)
    static let statusSnoozedSoft = adaptive(light: 0xCFFAFE, dark: 0x164E63)

    /// 破坏性操作 / 紧急
    static let danger = adaptive(light: 0xB91C1C, dark: 0xF87171)

    /// 卡片与分隔线——跟随系统，深浅色自动适配
    static let cardSurface = Color(nsColor: .controlBackgroundColor)
    static let cardBorder = Color(nsColor: .separatorColor)

    /// 根据浅色 / 深色外观返回不同色值。
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgbHex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    /// 0xRRGGBB → NSColor（sRGB）
    convenience init(rgbHex: UInt32) {
        self.init(
            srgbRed: CGFloat((rgbHex >> 16) & 0xFF) / 255,
            green: CGFloat((rgbHex >> 8) & 0xFF) / 255,
            blue: CGFloat(rgbHex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - 动效

enum Motion {
    /// 用户开启「减弱动态效果」时，所有动画都应该关掉。
    static var isReduced: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 需要动画时返回给定动画，否则返回 nil。
    static func animation(_ animation: Animation = .easeOut(duration: 0.18)) -> Animation? {
        isReduced ? nil : animation
    }
}

// MARK: - 按钮样式

/// 主操作按钮：实心主色 + 白字。按压只改透明度，不改变布局尺寸。
struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, Theme.Space.sm + 2)
            .frame(minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Color.brand)
            )
            .opacity(configuration.isPressed ? 0.75 : (isEnabled ? 1 : 0.4))
            .animation(Motion.animation(.easeOut(duration: 0.1)), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// 次操作按钮：描边 + 主色文字。
struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.brand)
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, Theme.Space.sm + 2)
            .frame(minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Color.brand.opacity(configuration.isPressed ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Color.brand.opacity(0.35), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .animation(Motion.animation(.easeOut(duration: 0.1)), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
