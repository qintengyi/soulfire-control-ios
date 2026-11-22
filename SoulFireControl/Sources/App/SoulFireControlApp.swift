import SwiftUI

@main
struct SoulFireControlApp: App {
    @State private var appVM = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appVM)
                .preferredColorScheme(.dark) // 固定深色 Minecraft 风
                .tint(MCTheme.redstone)
        }
    }
}

// MARK: - 根视图: 根据连接状态路由

struct RootView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        Group {
            switch appVM.connectionState {
            case .notConfigured:
                ServerSetupView()
            case .connecting:
                ProgressView("正在连接服务器…")
                    .foregroundStyle(MCTheme.textSecondary)
            case .connected:
                MainTabView()
            case .failed(let message):
                ServerSetupView(initialError: message)
            }
        }
        .background(MCTheme.background.ignoresSafeArea())
        .task { await appVM.connect() }
    }
}
