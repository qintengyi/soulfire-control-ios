import SwiftUI

// MARK: - 设置页

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var showDisconnectConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // 连接信息
                Section("服务器连接") {
                    if case .connected(let username, let version) = appVM.connectionState {
                        LabeledRow(label: "用户", value: username)
                        LabeledRow(label: "服务器版本", value: version)
                        if let info = appVM.clientData?.serverInfo {
                            LabeledRow(label: "MC 协议版本", value: info.minecraftVersion)
                            LabeledRow(label: "构建分支", value: info.branchName)
                        }
                        if let config = ServerConfigStore.load() {
                            LabeledRow(label: "地址", value: config.baseURLString)
                        }
                    }
                    Button(role: .destructive) {
                        showDisconnectConfirm = true
                    } label: {
                        Label("断开连接并清除 Token", systemImage: "trash")
                            .foregroundStyle(MCTheme.flame)
                    }
                }

                // 实例工具
                Section("当前实例工具") {
                    if let instanceId = appVM.selectedInstanceId {
                        NavigationLink {
                            AccountsView(instanceId: instanceId)
                        } label: {
                            Label("账号管理", systemImage: "person.crop.circle")
                                .foregroundStyle(MCTheme.textPrimary)
                        }
                        NavigationLink {
                            ProxiesView(instanceId: instanceId)
                        } label: {
                            Label("代理管理", systemImage: "network")
                                .foregroundStyle(MCTheme.textPrimary)
                        }
                        NavigationLink {
                            MetricsView(instanceId: instanceId)
                        } label: {
                            Label("指标监控", systemImage: "chart.bar")
                                .foregroundStyle(MCTheme.textPrimary)
                        }
                    } else {
                        Text("未选择实例")
                            .font(.system(size: 13))
                            .foregroundStyle(MCTheme.textTertiary)
                    }
                }

                // 关于
                Section("关于") {
                    LabeledRow(label: "App", value: "SoulFire Control 1.0.0")
                    LabeledRow(label: "API 契约", value: "SoulFire OpenAPI 2.11.0")
                    LabeledRow(label: "协议", value: "REST HTTP + Bearer JWT")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MCTheme.background)
            .navigationTitle("设置")
            .alert("断开连接", isPresented: $showDisconnectConfirm) {
                Button("断开并清除", role: .destructive) {
                    appVM.disconnect()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将删除 Keychain 中保存的 Token，需要重新输入才能再次连接。")
            }
        }
    }
}

// MARK: - 标签行

struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(MCTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(MCTheme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(1)
        }
    }
}
