import SwiftUI

// MARK: - Minecraft 深色主题
// 设计语言: 深色石板背景 + 红石红/火焰橙强调 + 方块感卡片

enum MCTheme {
    // MARK: 背景层
    static let background = Color(red: 0.09, green: 0.10, blue: 0.12)       // #171A1F 深石板
    static let backgroundElevated = Color(red: 0.13, green: 0.14, blue: 0.17) // #212429
    static let surface = Color(red: 0.16, green: 0.17, blue: 0.20)          // #292B33
    static let surfaceRaised = Color(red: 0.20, green: 0.21, blue: 0.25)     // #333640

    // MARK: 强调色
    static let redstone = Color(red: 0.85, green: 0.20, blue: 0.18)          // 红石红 #D93330
    static let flame = Color(red: 0.95, green: 0.55, blue: 0.15)             // 火焰橙 #F28C26
    static let diamond = Color(red: 0.25, green: 0.78, blue: 0.80)          // 钻石青 #40C7CC
    static let emerald = Color(red: 0.22, green: 0.70, blue: 0.36)           // 绿宝石 #38B35C
    static let gold = Color(red: 0.93, green: 0.75, blue: 0.20)              // 金锭 #EEBF33

    // MARK: 文字
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary = Color.white.opacity(0.38)

    // MARK: 状态色
    static let online = emerald
    static let offline = Color.white.opacity(0.25)
    static let connecting = flame
    static let failed = redstone
    static let retrying = gold
    static let stopped = Color.white.opacity(0.35)

    // MARK: 尺寸
    static let cornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let borderWidth: CGFloat = 1

    /// Minecraft 风格的卡片背景 (带描边)
    static func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(surfaceRaised, lineWidth: borderWidth)
            )
    }

    /// Minecraft 风格的按钮 (像素感: 平色填充 + 深色底边)
    static func mcButton(_ color: Color = redstone) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 1.5)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.28))
                    .frame(height: 3)
            }
    }

    /// 状态圆点
    static func statusDot(_ color: Color, size: CGFloat = 8) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - 便捷 Modifier

struct MCCardModifier: ViewModifier {
    var padding: CGFloat = MCTheme.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MCTheme.cardBackground())
    }
}

extension View {
    func mcCard(padding: CGFloat = MCTheme.cardPadding) -> some View {
        modifier(MCCardModifier(padding: padding))
    }
}

// MARK: - Minecraft 风格标题字体效果

struct MCPixelBadge: View {
    let text: String
    var color: Color = MCTheme.flame

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.85))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.black.opacity(0.4), lineWidth: 1))
            )
    }
}
