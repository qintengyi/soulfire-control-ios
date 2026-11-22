import SwiftUI

// MARK: - 代理管理

struct ProxiesView: View {
    let instanceId: String

    @State private var vm: ProxiesViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if vm == nil {
                let newVM = ProxiesViewModel(instanceId: instanceId)
                vm = newVM
                await newVM.loadProxies()
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: ProxiesViewModel) -> some View {
        let vm = self.vm ?? vm
        List {
            Section("添加代理") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("类型", selection: Binding(
                        get: { vm.type },
                        set: { vm.type = $0 }
                    )) {
                        ForEach(ProxyType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("host:port", text: Binding(
                        get: { vm.address },
                        set: { vm.address = $0 }
                    ))
                        .textFieldStyle(MCTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack(spacing: 10) {
                        TextField("用户名 (可选)", text: Binding(
                            get: { vm.username },
                            set: { vm.username = $0 }
                        ))
                            .textFieldStyle(MCTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("密码 (可选)", text: Binding(
                            get: { vm.password },
                            set: { vm.password = $0 }
                        ))
                            .textFieldStyle(MCTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Button {
                        Task { _ = await vm.addProxy() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("添加")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(MCTheme.mcButton(MCTheme.diamond))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
            }

            Section("批量添加") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("每行一个: host:port 或 socks5://user:pass@host:port")
                        .font(.system(size: 11))
                        .foregroundStyle(MCTheme.textTertiary)
                    TextEditor(text: Binding(
                        get: { vm.bulkText },
                        set: { vm.bulkText = $0 }
                    ))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: MCTheme.cornerRadiusSmall, style: .continuous)
                                .fill(MCTheme.backgroundElevated.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: MCTheme.cornerRadiusSmall, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                                )
                        )
                    Button {
                        Task { await vm.addBulkProxies() }
                    } label: {
                        Text("批量导入")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(MCTheme.mcButton(MCTheme.emerald))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
            }

            Section("代理列表 (\(vm.proxies.count))") {
                ForEach(Array(vm.proxies.enumerated()), id: \.element.id) { index, proxy in
                    proxyRow(proxy, index: index)
                }
                .onDelete { offsets in
                    Task {
                        for index in offsets {
                            await vm.removeProxy(index: index)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(MCTheme.background)
        .navigationTitle("代理管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                RefreshButton { Task { await vm.loadProxies() } }
            }
        }
        .overlay {
            if vm.proxies.isEmpty && !vm.isLoading {
                EmptyStateView(icon: "network.badge.shield.half.filled", title: "暂无代理", subtitle: nil)
            }
        }
    }

    private func proxyRow(_ proxy: Proxy, index: Int) -> some View {
        HStack(spacing: 10) {
            MCPixelBadge(text: proxy.type, color: proxyColor(proxy.type))
            VStack(alignment: .leading, spacing: 2) {
                Text(proxy.address)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(MCTheme.textPrimary)
                if let user = proxy.username {
                    Text("认证: \(user)")
                        .font(.system(size: 11))
                        .foregroundStyle(MCTheme.textTertiary)
                }
            }
            Spacer()
            Text("#\(index)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(MCTheme.textTertiary)
        }
    }

    private func proxyColor(_ type: String) -> Color {
        switch ProxyType(rawValue: type) {
        case .http: return MCTheme.diamond
        case .socks4: return MCTheme.gold
        case .socks5: return MCTheme.emerald
        case nil: return MCTheme.textTertiary
        }
    }
}
