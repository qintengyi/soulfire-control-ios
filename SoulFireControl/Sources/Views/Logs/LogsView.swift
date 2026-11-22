import SwiftUI

// MARK: - 日志 Tab (全局日志 / 实例日志切换)

struct LogsTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var scopeMode = 0 // 0=全局, 1=当前实例

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("作用域", selection: $scopeMode) {
                    Text("全局").tag(0)
                    Text("当前实例").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                if scopeMode == 0 {
                    LogsView(scope: LogScope(global: EmptyObject(), instance: nil, bot: nil))
                } else if let instanceId = appVM.selectedInstanceId {
                    LogsView(scope: LogScope.instanceScope(instanceId))
                } else {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "未选择实例",
                        subtitle: "在「实例」页选择一个实例后查看其日志"
                    )
                }
            }
            .navigationTitle("日志")
        }
    }
}

// MARK: - 日志列表

struct LogsView: View {
    @Environment(AppViewModel.self) private var appVM

    let scope: LogScope
    @State private var vm: LogsViewModel?

    var body: some View {
        Group {
            if let vm {
                logContent(vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if vm == nil {
                let newVM = LogsViewModel(scope: scope)
                vm = newVM
                await newVM.loadLogs()
                newVM.startAutoRefresh()
            }
        }
        .onDisappear {
            vm?.stopAutoRefresh()
        }
    }

    @ViewBuilder
    private func logContent(_ vm: LogsViewModel) -> some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MCTheme.textTertiary)
                TextField("搜索日志…", text: $vm.searchText)
                    .font(.system(size: 13))
                    .foregroundStyle(MCTheme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(MCTheme.backgroundElevated)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            HStack {
                Toggle(isOn: $vm.autoRefresh) {
                    Text("自动刷新 (3s)")
                        .font(.system(size: 12))
                        .foregroundStyle(MCTheme.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(MCTheme.emerald)
                Spacer()
                Text("\(vm.filteredLogs.count) 条")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(MCTheme.textTertiary)
                RefreshButton { Task { await vm.loadLogs() } }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            if let error = vm.errorMessage, vm.logs.isEmpty {
                ErrorStateView(message: error) {
                    Task { await vm.loadLogs() }
                }
                Spacer()
            } else if vm.filteredLogs.isEmpty {
                EmptyStateView(icon: "doc.text", title: "暂无日志", subtitle: nil)
                Spacer()
            } else {
                // 日志流 (倒序显示, 最新在上)
                let logs = Array(vm.filteredLogs.reversed())
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(logs) { entry in
                            LogRow(entry: entry)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }
}

// MARK: - 单条日志

struct LogRow: View {
    let entry: LogEntry

    private var levelColor: Color {
        switch (entry.level ?? "").uppercased() {
        case "ERROR", "FATAL": return MCTheme.failed
        case "WARN": return MCTheme.gold
        case "INFO": return MCTheme.diamond
        case "DEBUG", "TRACE": return MCTheme.textTertiary
        default: return MCTheme.textSecondary
        }
    }

    private var isError: Bool {
        (entry.level ?? "").uppercased() == "ERROR"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(entry.level ?? "LOG")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(levelColor)
                    .frame(width: 42, alignment: .leading)
                if let instanceName = entry.instanceName {
                    Text(instanceName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MCTheme.flame.opacity(0.8))
                        .lineLimit(1)
                }
                if let botName = entry.botAccountName {
                    Text("· \(botName)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MCTheme.diamond.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer()
                Text(HumanTime.format(entry.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MCTheme.textTertiary)
            }
            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isError ? MCTheme.redstone.opacity(0.9) : MCTheme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(isError ? MCTheme.redstone.opacity(0.06) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MCTheme.surface.opacity(0.5))
                .frame(height: 0.5)
        }
    }
}
