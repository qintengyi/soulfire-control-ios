import SwiftUI

// MARK: - 主 Tab 布局

struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedTab: Tab = .instances

    enum Tab: Hashable {
        case instances, bots, logs, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            InstancesView()
                .tabItem { Label("实例", systemImage: "cube.fill") }
                .tag(Tab.instances)

            InstanceBotsView(instanceId: appVM.selectedInstanceId)
                .tabItem { Label("Bot", systemImage: "person.2.fill") }
                .tag(Tab.bots)

            LogsTabView()
                .tabItem { Label("日志", systemImage: "doc.text.fill") }
                .tag(Tab.logs)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .overlay(alignment: .top) { ToastOverlay() }
    }
}

// MARK: - 全局 Toast / Error

struct ToastOverlay: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(spacing: 8) {
            if let error = appVM.globalError {
                toastCard(error, color: MCTheme.redstone, icon: "xmark.octagon.fill")
            }
            if let toast = appVM.globalToast {
                toastCard(toast, color: MCTheme.emerald, icon: "checkmark.circle.fill")
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(duration: 0.3), value: appVM.globalToast)
        .animation(.spring(duration: 0.3), value: appVM.globalError)
    }

    private func toastCard(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MCTheme.textPrimary)
                .lineLimit(3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MCTheme.surface.opacity(0.98))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.5), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(MCTheme.textTertiary)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MCTheme.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(MCTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 加载失败

struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(MCTheme.flame)
            Text("加载失败")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MCTheme.textPrimary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(MCTheme.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button {
                    retry()
                } label: {
                    Text("重试")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(MCTheme.mcButton(MCTheme.diamond))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 状态徽标

struct StatusBadge: View {
    let text: String
    let color: Color

    init(_ text: String, _ color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(0.15))
                    .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
            )
    }
}

// MARK: - 刷新按钮

struct RefreshButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MCTheme.diamond)
        }
        .buttonStyle(.plain)
    }
}
