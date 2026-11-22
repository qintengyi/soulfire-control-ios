import SwiftUI

// MARK: - 账号管理

struct AccountsView: View {
    let instanceId: String

    @State private var vm: AccountsViewModel?
    @State private var selectedAccountIds = Set<String>()
    @State private var showBulkRemoveConfirm = false

    var body: some View {
        Group {
            if vm != nil {
                content()
            } else {
                ProgressView()
            }
        }
        .task {
            if vm == nil {
                let newVM = AccountsViewModel(instanceId: instanceId)
                vm = newVM
                await newVM.loadAccounts()
            }
        }
    }

    @ViewBuilder
    private func content() -> some View {
        // vm 在调用前已确保非空 (body 中 if let vm)
        let vm = self.vm!
        List {
            // 批量添加离线账号
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("添加离线账号 (每行一个用户名，支持逗号分隔)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MCTheme.textSecondary)
                    TextEditor(text: Binding(
                        get: { vm.offlineUsernames },
                        set: { vm.offlineUsernames = $0 }
                    ))
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(MCTheme.backgroundElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(MCTheme.surfaceRaised, lineWidth: 1)
                        )
                    Button {
                        Task { await vm.addOfflineAccounts() }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isAdding { ProgressView().tint(.white) }
                            Image(systemName: "person.badge.plus")
                            Text(vm.isAdding ? "添加中…" : "批量添加")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(MCTheme.mcButton(MCTheme.emerald))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isAdding)
                }
                .padding(.vertical, 6)
            } header: {
                Text("离线账号")
            }

            // 账号列表
            Section {
                ForEach(vm.accounts) { account in
                    accountRow(vm, account)
                }
                .onDelete { offsets in
                    let ids = offsets.map { vm.accounts[$0].profileId }
                    Task { await vm.removeSelected(profileIds: ids) }
                }
            } header: {
                HStack {
                    Text("已有账号 (\(vm.accounts.count))")
                    Spacer()
                    if !selectedAccountIds.isEmpty {
                        Button("删除所选") { showBulkRemoveConfirm = true }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MCTheme.flame)
                    }
                }
            } footer: {
                Text("账号类型支持 OFFLINE / MICROSOFT_JAVA / THE_ALTENING 等。此 App 支持离线账号一键添加，微软账号请在桌面端添加后自动同步。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(MCTheme.background)
        .navigationTitle("账号管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("批量删除", isPresented: $showBulkRemoveConfirm) {
            Button("删除 \(selectedAccountIds.count) 个", role: .destructive) {
                Task {
                    await vm.removeSelected(profileIds: Array(selectedAccountIds))
                    selectedAccountIds.removeAll()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定删除所选账号？相关 bot 将停止。")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                RefreshButton { Task { await vm.loadAccounts() } }
            }
        }
        .overlay {
            if vm.accounts.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "暂无账号",
                    subtitle: "在上方输入用户名批量添加离线账号"
                )
            }
        }
    }

    private func accountRow(_ vm: AccountsViewModel, _ account: MinecraftAccount) -> some View {
        HStack(spacing: 12) {
            // 头像方块
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(typeColor(account.type).opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(typeColor(account.type))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(account.lastKnownName ?? "未知")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MCTheme.textPrimary)
                Text(typeDisplay(account.type))
                    .font(.system(size: 11))
                    .foregroundStyle(MCTheme.textTertiary)
            }

            Spacer()

            MCPixelBadge(text: typeShort(account.type), color: typeColor(account.type))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedAccountIds.contains(account.profileId) {
                selectedAccountIds.remove(account.profileId)
            } else {
                selectedAccountIds.insert(account.profileId)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(selectedAccountIds.contains(account.profileId) ? MCTheme.diamond : .clear, lineWidth: 2)
        )
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "OFFLINE": return MCTheme.gold
        case "MICROSOFT_JAVA_CREDENTIALS", "MICROSOFT_JAVA_DEVICE_CODE", "MICROSOFT_JAVA_REFRESH_TOKEN",
             "MICROSOFT_JAVA_COOKIES", "MICROSOFT_JAVA_ACCESS_TOKEN":
            return MCTheme.diamond
        case "MICROSOFT_BEDROCK_CREDENTIALS", "MICROSOFT_BEDROCK_DEVICE_CODE":
            return MCTheme.emerald
        case "THE_ALTENING":
            return MCTheme.flame
        default: return MCTheme.textTertiary
        }
    }

    private func typeDisplay(_ type: String) -> String {
        switch type {
        case "OFFLINE": return "离线模式 (Java)"
        case "MICROSOFT_JAVA_CREDENTIALS": return "微软登录 (Java)"
        case "MICROSOFT_JAVA_DEVICE_CODE": return "微软设备码 (Java)"
        case "MICROSOFT_JAVA_REFRESH_TOKEN": return "微软刷新令牌 (Java)"
        case "MICROSOFT_JAVA_COOKIES": return "微软 Cookie (Java)"
        case "MICROSOFT_JAVA_ACCESS_TOKEN": return "Access Token (Java)"
        case "MICROSOFT_BEDROCK_CREDENTIALS": return "微软登录 (Bedrock)"
        case "MICROSOFT_BEDROCK_DEVICE_CODE": return "微软设备码 (Bedrock)"
        case "THE_ALTENING": return "TheAltening (Java)"
        default: return type
        }
    }

    private func typeShort(_ type: String) -> String {
        switch type {
        case "OFFLINE": return "离线"
        case "THE_ALTENING": return "TA"
        default:
            if type.contains("BEDROCK") { return "基岩" }
            if type.contains("MICROSOFT") { return "正版" }
            return "—"
        }
    }
}
