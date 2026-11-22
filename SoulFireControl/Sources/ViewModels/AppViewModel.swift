import SwiftUI
import Observation

// MARK: - 应用根 ViewModel
// 管理连接状态、当前选中实例、全局错误提示

@Observable
final class AppViewModel {
    // 连接状态
    enum ConnectionState: Equatable {
        case notConfigured
        case connecting
        case connected(username: String, serverVersion: String)
        case failed(String)
    }

    var connectionState: ConnectionState = .notConfigured
    var clientData: ClientDataResponse?

    // 当前选中的实例
    var selectedInstanceId: String? {
        didSet { persistSelectedInstance() }
    }
    var selectedInstanceName: String = ""

    // 全局提示
    var globalToast: String?
    var globalError: String?

    private let selectedInstanceKey = "selected_instance_id"

    init() {
        // 启动时恢复配置到 APIClient
        if let config = ServerConfigStore.load() {
            APIClient.shared.updateConfig(
                baseURL: URL(string: config.baseURLString),
                token: KeychainStore.loadToken()
            )
        }
        selectedInstanceId = UserDefaults.standard.string(forKey: selectedInstanceKey)
    }

    func persistSelectedInstance() {
        if let id = selectedInstanceId {
            UserDefaults.standard.set(id, forKey: selectedInstanceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedInstanceKey)
        }
    }

    // MARK: 连接

    @MainActor
    func connect() async {
        guard APIClient.shared.isConfigured else {
            connectionState = .notConfigured
            return
        }
        connectionState = .connecting
        do {
            let data = try await SoulFireAPI.getClientData()
            clientData = data
            connectionState = .connected(username: data.username, serverVersion: data.serverInfo.version)
        } catch {
            let apiError = error as? APIError ?? .networkFailed(error)
            connectionState = .failed(apiError.localizedDescription ?? "连接失败")
        }
    }

    /// 配置并连接
    @MainActor
    func configure(host: String, port: Int, useHTTPS: Bool, token: String) async -> Bool {
        let config = ServerConfig(host: host, port: port, useHTTPS: useHTTPS)
        ServerConfigStore.save(config)
        KeychainStore.saveToken(token)
        APIClient.shared.updateConfig(
            baseURL: URL(string: config.baseURLString),
            token: token
        )
        await connect()
        if case .connected = connectionState { return true }
        return false
    }

    @MainActor
    func disconnect() {
        KeychainStore.deleteToken()
        APIClient.shared.updateConfig(baseURL: nil, token: nil)
        connectionState = .notConfigured
        clientData = nil
        selectedInstanceId = nil
    }

    func showToast(_ message: String) {
        globalToast = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if globalToast == message { globalToast = nil }
        }
    }

    func showError(_ message: String) {
        globalError = message
        Task {
            try? await Task.sleep(for: .seconds(4))
            if globalError == message { globalError = nil }
        }
    }
}
