import SwiftUI

// MARK: - 首次启动: 服务器连接配置

struct ServerSetupView: View {
    @Environment(AppViewModel.self) private var appVM

    var initialError: String?

    @State private var host: String = ""
    @State private var port: String = "38765"
    @State private var useHTTPS = false
    @State private var token: String = ""
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorText = ""

    init(initialError: String? = nil) {
        self.initialError = initialError
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo 区域
                VStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [MCTheme.flame, MCTheme.redstone],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Text("SoulFire Control")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(MCTheme.textPrimary)
                    Text("Minecraft Bot 控制台")
                        .font(.system(size: 14))
                        .foregroundStyle(MCTheme.textSecondary)
                }
                .padding(.top, 48)

                // 表单
                VStack(alignment: .leading, spacing: 16) {
                    Text("连接到你的 SoulFire 服务器")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MCTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("服务器地址")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MCTheme.textSecondary)
                        TextField("例如 192.168.1.2 或 sf.example.com", text: $host)
                            .textFieldStyle(MCTextFieldStyle())
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("端口")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(MCTheme.textSecondary)
                            TextField("38765", text: $port)
                                .textFieldStyle(MCTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        Toggle(isOn: $useHTTPS) {
                            Text("HTTPS")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(MCTheme.textSecondary)
                        }
                        .toggleStyle(.switch)
                        .tint(MCTheme.diamond)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Token")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MCTheme.textSecondary)
                        SecureField("在服务器终端执行 generate-token api 获取", text: $token)
                            .textFieldStyle(MCTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Text("Token 在 SoulFire 服务器终端中执行 `generate-token api` 生成，仅对当前用户权限生效。")
                        .font(.system(size: 11))
                        .foregroundStyle(MCTheme.textTertiary)
                }
                .mcCard(padding: 18)

                // 连接按钮
                Button {
                    Task { await connect() }
                } label: {
                    HStack(spacing: 8) {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(isConnecting ? "连接中…" : "连接")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        MCTheme.mcButton(isConnecting ? MCTheme.surfaceRaised : MCTheme.redstone)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isConnecting || host.isEmpty || token.isEmpty)

                // 错误信息: 优先显示本次连接错误, 其次显示初始错误
                if showError {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundStyle(MCTheme.redstone)
                        .multilineTextAlignment(.center)
                } else if let initialError {
                    Text(initialError)
                        .font(.system(size: 13))
                        .foregroundStyle(MCTheme.redstone)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(MCTheme.background.ignoresSafeArea())
    }

    private func connect() async {
        guard let portNum = Int(port), portNum > 0 && portNum < 65536 else {
            errorText = "端口无效 (1-65535)"
            showError = true
            return
        }
        isConnecting = true
        showError = false
        let ok = await appVM.configure(host: host, port: portNum, useHTTPS: useHTTPS, token: token)
        if !ok {
            if case .failed(let msg) = appVM.connectionState {
                errorText = msg
            } else {
                errorText = "连接失败，请检查配置"
            }
            showError = true
        }
        isConnecting = false
    }
}

// MARK: - 文本框风格

struct MCTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.system(size: 15))
            .foregroundStyle(MCTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: MCTheme.cornerRadiusSmall, style: .continuous)
                    .fill(MCTheme.backgroundElevated.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: MCTheme.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
    }
}
