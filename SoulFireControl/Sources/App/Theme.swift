import SwiftUI

// MARK: - Minecraft 深色主题 (iOS 现代风格)
// 设计语言: 深色石板背景 + 红石红/火焰橙强调 + 柔和圆角卡片 + 毛玻璃边框

enum MCTheme {
    // MARK: 背景层
    static let background = Color(red: 0.07, green: 0.08, blue: 0.10)        // #121418 更深的底
    static let backgroundElevated = Color(red: 0.11, green: 0.12, blue: 0.15) // #1C1F26
    static let surface = Color(red: 0.14, green: 0.15, blue: 0.18)           // #242730
    static let surfaceRaised = Color(red: 0.20, green: 0.21, blue: 0.26)     // #333642

    // MARK: 强调色 (略微提亮, 在深色底上更跳)
    static let redstone = Color(red: 0.92, green: 0.28, blue: 0.24)          // 红石红 #EB473D
    static let flame = Color(red: 0.98, green: 0.60, blue: 0.20)             // 火焰橙 #FA9933
    static let diamond = Color(red: 0.30, green: 0.82, blue: 0.85)           // 钻石青 #4DD1D9
    static let emerald = Color(red: 0.28, green: 0.76, blue: 0.42)           // 绿宝石 #47C26B
    static let gold = Color(red: 0.96, green: 0.80, blue: 0.28)              // 金锭 #F5CC48

    // MARK: 文字
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.40)

    // MARK: 状态色
    static let online = emerald
    static let offline = Color.white.opacity(0.28)
    static let connecting = flame
    static let failed = redstone
    static let retrying = gold
    static let stopped = Color.white.opacity(0.38)

    // MARK: 尺寸 (iOS 现代风格: 更大圆角)
    static let cornerRadius: CGFloat = 16          // 卡片大圆角
    static let cornerRadiusSmall: CGFloat = 12     // 按钮圆角
    static let cornerRadiusTiny: CGFloat = 8       // 小元素
    static let cardPadding: CGFloat = 16
    static let borderWidth: CGFloat = 0.5          // 更细的描边

    // MARK: 卡片背景 (毛玻璃 + 柔光描边 + 阴影)
    static func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: borderWidth
                    )
            )
            .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 4)
    }

    // MARK: 按钮 (渐变 + 柔光, 去掉像素底边)
    static func mcButton(_ color: Color = redstone) -> some View {
        RoundedRectangle(cornerRadius: cornerRadiusSmall, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.95), color.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadiusSmall, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 2)
    }

    // MARK: 状态圆点 (带内发光)
    static func statusDot(_ color: Color, size: CGFloat = 8) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.6), radius: 3)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
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

// MARK: - 标题徽标 (柔和胶囊)

struct MCPixelBadge: View {
    let text: String
    var color: Color = MCTheme.flame

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.85))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
            )
    }
}
