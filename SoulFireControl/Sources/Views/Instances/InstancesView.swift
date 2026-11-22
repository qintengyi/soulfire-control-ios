import SwiftUI

// MARK: - 实例列表

struct InstancesView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var vm = InstancesViewModel()
    @State private var showCreateSheet = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.instances.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.instances.isEmpty {
                    ErrorStateView(message: error) {
                        Task { await vm.loadInstances() }
                    }
                } else if vm.instances.isEmpty {
                    EmptyStateView(
                        icon: "cube.transparent",
                        title: "还没有实例",
                        subtitle: "点击右上角 + 创建你的第一个 SoulFire 实例"
                    )
                } else {
                    List {
                        ForEach(vm.instances) { instance in
                            InstanceRow(
                                instance: instance,
                                isSelected: appVM.selectedInstanceId == instance.id,
                                onSelect: { appVM.selectedInstanceId = instance.id },
                                onDelete: { confirmDelete(instance) }
                            )
                            .listRowBackground(MCTheme.background)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("实例")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        RefreshButton { Task { await vm.loadInstances() } }
                        Button {
                            newName = ""
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MCTheme.redstone)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                createSheet
            }
            .alert("删除实例", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) { Task { await doDelete() } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将永久删除实例「\(pendingDeleteName)」及其全部配置，不可恢复。")
            }
            .task {
                await vm.loadInstances()
                // 自动选择: 恢复上次选择或第一个
                if appVM.selectedInstanceId == nil, let first = vm.instances.first {
                    appVM.selectedInstanceId = first.id
                }
            }
            .refreshable { await vm.loadInstances() }
        }
    }

    // MARK: 创建 Sheet

    private var createSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("实例名称")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MCTheme.textSecondary)
                TextField("例如 压力测试服", text: $newName)
                    .textFieldStyle(MCTextFieldStyle())
                Text("创建后可在实例内添加 Minecraft 账号和代理。")
                    .font(.system(size: 11))
                    .foregroundStyle(MCTheme.textTertiary)
                Spacer()
            }
            .padding(20)
            .background(MCTheme.background.ignoresSafeArea())
            .navigationTitle("新建实例")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showCreateSheet = false }
                        .foregroundStyle(MCTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        Task {
                            if await vm.createInstance(name: newName) {
                                showCreateSheet = false
                                appVM.showToast("实例已创建")
                            }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MCTheme.emerald)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(260)])
        .presentationBackground(MCTheme.background)
    }

    // MARK: 删除确认

    @State private var showDeleteConfirm = false
    @State private var pendingDeleteId: String?
    @State private var pendingDeleteName = ""

    private func confirmDelete(_ instance: InstanceSummary) {
        pendingDeleteId = instance.id
        pendingDeleteName = instance.friendlyName
        showDeleteConfirm = true
    }

    private func doDelete() async {
        guard let id = pendingDeleteId else { return }
        if await vm.deleteInstance(id: id) {
            appVM.showToast("实例已删除")
            if appVM.selectedInstanceId == id {
                appVM.selectedInstanceId = vm.instances.first?.id
            }
        }
    }
}

// MARK: - 实例行

struct InstanceRow: View {
    let instance: InstanceSummary
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 图标方块
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? MCTheme.redstone.opacity(0.25) : MCTheme.surfaceRaised)
                        .frame(width: 44, height: 44)
                    Image(systemName: "cube.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? MCTheme.redstone : MCTheme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(instance.friendlyName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MCTheme.textPrimary)
                        if isSelected {
                            MCPixelBadge(text: "当前", color: MCTheme.diamond)
                        }
                    }
                    if let summary = instance.botSummary {
                        Text("\(summary.onlineBots) 在线 / \(summary.desiredBots) 目标 / 共 \(summary.totalBots)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(MCTheme.textSecondary)
                    }
                }

                Spacer()

                if let summary = instance.botSummary {
                    // 小型在线率指示
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusBadge(
                            summary.failedBots > 0 ? "\(summary.failedBots) 失败" : "\(summary.onlineBots) 在线",
                            summary.failedBots > 0 ? MCTheme.failed : (summary.onlineBots > 0 ? MCTheme.online : MCTheme.stopped)
                        )
                        if summary.startingBots > 0 {
                            StatusBadge("\(summary.startingBots) 启动中", MCTheme.connecting)
                        }
                    }
                }
            }
            .mcCard(padding: 12)
            .overlay(
                RoundedRectangle(cornerRadius: MCTheme.cornerRadius)
                    .strokeBorder(isSelected ? MCTheme.redstone.opacity(0.6) : .clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: MCTheme.cornerRadius))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("删除实例", systemImage: "trash")
            }
        }
    }
}
