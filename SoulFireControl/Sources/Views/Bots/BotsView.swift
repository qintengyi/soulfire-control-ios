import SwiftUI

// MARK: - Bot Tab 入口 (绑定当前选中实例)

struct InstanceBotsView: View {
    let instanceId: String?

    var body: some View {
        if let instanceId {
            BotsView(instanceId: instanceId)
        } else {
            NavigationStack {
                EmptyStateView(
                    icon: "person.2",
                    title: "未选择实例",
                    subtitle: "请先在「实例」页选择或创建一个实例"
                )
            }
        }
    }
}

// MARK: - Bot 列表

struct BotsView: View {
    @Environment(AppViewModel.self) private var appVM
    let instanceId: String

    @State private var vm: BotsViewModel?
    @State private var selection = Set<String>()
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    botList(vm)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Bots")
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if editMode == .active {
                        Button("完成") {
                            editMode = .inactive
                            selection.removeAll()
                        }
                        .foregroundStyle(MCTheme.diamond)
                    } else {
                        Button {
                            editMode = .active
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(MCTheme.textSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        if editMode == .active, !selection.isEmpty {
                            Button {
                                Task { await vm?.setDesired(running: true, botIds: Array(selection)) }
                                selection.removeAll()
                            } label: {
                                Image(systemName: "play.fill")
                                    .foregroundStyle(MCTheme.emerald)
                            }
                            Button {
                                Task { await vm?.setDesired(running: false, botIds: Array(selection)) }
                                selection.removeAll()
                            } label: {
                                Image(systemName: "stop.fill")
                                    .foregroundStyle(MCTheme.flame)
                            }
                        }
                        if editMode == .inactive {
                            RefreshButton { Task { await vm?.loadBots() } }
                            Menu {
                                Button {
                                    Task { await vm?.setDesired(running: true, botIds: vm?.bots.map(\.profileId) ?? []) }
                                } label: {
                                    Label("启动全部", systemImage: "play.fill")
                                }
                                Button {
                                    Task { await vm?.setDesired(running: false, botIds: vm?.bots.map(\.profileId) ?? []) }
                                } label: {
                                    Label("停止全部", systemImage: "stop.fill")
                                }
                                Button {
                                    Task { await vm?.restart(botIds: vm?.bots.map(\.profileId) ?? []) }
                                } label: {
                                    Label("重启全部", systemImage: "arrow.triangle.2.circlepath")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(MCTheme.diamond)
                            }
                        }
                    }
                }
            }
            .task {
                if vm == nil {
                    let newVM = BotsViewModel(instanceId: instanceId)
                    vm = newVM
                    await newVM.loadBots()
                    newVM.startAutoRefresh()
                }
            }
            .onDisappear {
                vm?.stopAutoRefresh()
            }
        }
    }

    @ViewBuilder
    private func botList(_ vm: BotsViewModel) -> some View {
        List(selection: $selection) {
            ForEach(filteredBots) { bot in
                NavigationLink {
                    BotDetailView(instanceId: instanceId, bot: bot)
                } label: {
                    BotRow(bot: bot, isSelected: selection.contains(bot.profileId))
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if bot.desiredRunning {
                        Button(role: .destructive) {
                            Task { await vm.setDesired(running: false, botIds: [bot.profileId]) }
                        } label: { Label("停止", systemImage: "stop.fill") }
                    } else {
                        Button {
                            Task { await vm.setDesired(running: true, botIds: [bot.profileId]) }
                        } label: { Label("启动", systemImage: "play.fill") }
                            .tint(MCTheme.emerald)
                    }
                }
                .listRowBackground(MCTheme.background)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await vm.loadBots() }
        .searchable(text: $searchText, prompt: "搜索 bot 名称")
        .overlay {
            if vm.bots.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: "person.2",
                    title: "暂无 Bot",
                    subtitle: "先在「账号」页添加 Minecraft 账号，再启动 bot"
                )
            }
        }
    }

    @State private var searchText = ""

    private var filteredBots: [BotListEntry] {
        guard let vm else { return [] }
        guard !searchText.isEmpty else { return vm.bots }
        return vm.bots.filter { bot in
            (bot.accountName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Bot 行

struct BotRow: View {
    let bot: BotListEntry
    let isSelected: Bool

    private var statusColor: Color {
        switch bot.status.runtimeState {
        case "BOT_RUNTIME_STATE_RUNNING": return MCTheme.online
        case "BOT_RUNTIME_STATE_STARTING", "BOT_RUNTIME_STATE_QUEUED": return MCTheme.connecting
        case "BOT_RUNTIME_STATE_RETRYING": return MCTheme.retrying
        case "BOT_RUNTIME_STATE_FAILED": return MCTheme.failed
        case "BOT_RUNTIME_STATE_STOPPING": return MCTheme.gold
        default: return MCTheme.stopped
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            MCTheme.statusDot(statusColor)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(bot.accountName ?? String(bot.profileId.prefix(8)))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MCTheme.textPrimary)
                    if bot.status.desiredState == "BOT_DESIRED_STATE_STOPPED" {
                        MCPixelBadge(text: "停", color: MCTheme.stopped)
                    }
                }
                HStack(spacing: 8) {
                    Text(bot.runtimeStateDisplay)
                        .foregroundStyle(statusColor)
                    if let ping = bot.pingMs {
                        Text("· \(ping)ms")
                            .foregroundStyle(MCTheme.textTertiary)
                    }
                    if let live = bot.liveState {
                        Text("· ❤️\(Int(live.health ?? 0))/\(Int(live.maxHealth ?? 20))")
                            .foregroundStyle(MCTheme.textTertiary)
                        if let x = live.x, let y = live.y, let z = live.z {
                            Text("· \(Int(x)), \(Int(y)), \(Int(z))")
                                .foregroundStyle(MCTheme.textTertiary)
                        }
                    }
                }
                .font(.system(size: 12, design: .monospaced))
            }

            Spacer()

            // 启停快捷按钮
            if bot.desiredRunning {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(MCTheme.flame.opacity(0.85))
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(MCTheme.emerald.opacity(0.85))
            }
        }
        .mcCard(padding: 12)
        .overlay(
            RoundedRectangle(cornerRadius: MCTheme.cornerRadius, style: .continuous)
                .strokeBorder(isSelected ? MCTheme.diamond.opacity(0.5) : .clear, lineWidth: 1)
        )
    }
}
