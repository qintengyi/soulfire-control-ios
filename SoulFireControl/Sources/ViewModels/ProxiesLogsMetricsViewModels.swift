import SwiftUI
import Observation

// MARK: - 代理管理 VM

@Observable
final class ProxiesViewModel {
    let instanceId: String

    var proxies: [Proxy] = []
    var isLoading = false
    var errorMessage: String?
    var actionMessage: String?

    // 添加表单
    var type: ProxyType = .socks5
    var address = ""
    var username = ""
    var password = ""

    // 批量文本: 每行 protocol://user:pass@host:port 或 host:port
    var bulkText = ""

    init(instanceId: String) {
        self.instanceId = instanceId
    }

    @MainActor
    func loadProxies() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await SoulFireAPI.getInstanceInfo(id: instanceId)
            proxies = info?.config.proxies ?? []
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    @MainActor
    func addProxy() async -> Bool {
        let addr = address.trimmingCharacters(in: .whitespaces)
        guard !addr.isEmpty else {
            actionMessage = "请填写代理地址 (host:port)"
            return false
        }
        let proxy = Proxy(
            type: type.rawValue,
            address: addr,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password
        )
        do {
            try await SoulFireAPI.addProxy(instanceId: instanceId, proxy: proxy)
            address = ""; username = ""; password = ""
            actionMessage = "代理已添加"
            await loadProxies()
            return true
        } catch {
            actionMessage = "添加失败：\((error as? APIError)?.localizedDescription ?? "")"
            return false
        }
    }

    /// 解析批量文本。支持的行格式:
    ///   host:port
    ///   socks5://host:port
    ///   http://user:pass@host:port
    ///   socks5:host:port:user:pass
    static func parseBulk(_ raw: String) -> [Proxy] {
        var result: [Proxy] = []
        for rawLine in raw.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            var type: ProxyType = .socks5
            var userInfo: String? = nil
            var hostPort: String = line

            if let schemeEnd = line.range(of: "://") {
                let scheme = String(line[..<schemeEnd.lowerBound])
                switch scheme.lowercased() {
                case "http", "https": type = .http
                case "socks4": type = .socks4
                case "socks5", "socks": type = .socks5
                default: break
                }
                hostPort = String(line[schemeEnd.upperBound...])
            }

            // user:pass@host:port
            if let at = hostPort.lastIndex(of: "@") {
                userInfo = String(hostPort[..<at])
                hostPort = String(hostPort[hostPort.index(after: at)...])
            }

            var username: String? = nil
            var password: String? = nil
            if let userInfo {
                let parts = userInfo.split(separator: ":", maxSplits: 1)
                username = String(parts.first ?? "")
                if parts.count > 1 { password = String(parts[1]) }
            }

            guard hostPort.contains(":") else {
                // 仅有 host 无端口, 跳过
                continue
            }

            result.append(Proxy(
                type: type.rawValue,
                address: hostPort,
                username: username,
                password: password
            ))
        }
        return result
    }

    @MainActor
    func addBulkProxies() async {
        let parsed = Self.parseBulk(bulkText)
        guard !parsed.isEmpty else {
            actionMessage = "未解析到有效代理行"
            return
        }
        do {
            try await SoulFireAPI.batchAddProxies(instanceId: instanceId, proxies: parsed)
            bulkText = ""
            actionMessage = "已添加 \(parsed.count) 个代理"
            await loadProxies()
        } catch {
            actionMessage = "批量添加失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }

    @MainActor
    func removeProxy(index: Int) async {
        do {
            try await SoulFireAPI.removeProxy(instanceId: instanceId, index: index)
            actionMessage = "代理已删除"
            await loadProxies()
        } catch {
            actionMessage = "删除失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }
}

// MARK: - 日志 VM

@Observable
final class LogsViewModel {
    var logs: [LogEntry] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    var autoRefresh = true
    private var refreshTask: Task<Void, Never>?

    // 作用域: nil = 全局, 或 instance/bot
    let scope: LogScope

    init(scope: LogScope?) {
        self.scope = scope ?? LogScope(global: EmptyObject(), instance: nil, bot: nil)
    }

    @MainActor
    func loadLogs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            logs = try await SoulFireAPI.getLogHistory(scope: scope, count: 300)
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        guard autoRefresh else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await self?.loadLogs()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    var filteredLogs: [LogEntry] {
        guard !searchText.isEmpty else { return logs }
        return logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - 指标 VM

@Observable
final class MetricsViewModel {
    var instanceMetrics: GetInstanceMetricsResponse?
    var serverMetrics: [ServerMetricsSnapshot] = []
    var isLoading = false
    var errorMessage: String?

    let instanceId: String

    init(instanceId: String) {
        self.instanceId = instanceId
    }

    @MainActor
    func loadMetrics() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let inst = SoulFireAPI.getInstanceMetrics(instanceId: instanceId)
            async let srv = SoulFireAPI.getServerMetrics()
            instanceMetrics = try await inst
            serverMetrics = try await srv
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    var latestServerSnapshot: ServerMetricsSnapshot? {
        serverMetrics.last
    }

    var latestInstanceSnapshot: MetricsSnapshot? {
        instanceMetrics?.snapshots.last
    }
}
