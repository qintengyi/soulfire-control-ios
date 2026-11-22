import SwiftUI
import Observation

// MARK: - 实例列表 VM

@Observable
final class InstancesViewModel {
    var instances: [InstanceSummary] = []
    var isLoading = false
    var errorMessage: String?

    @MainActor
    func loadInstances() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            instances = try await SoulFireAPI.listInstances()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    @MainActor
    func createInstance(name: String) async -> String? {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        do {
            let id = try await SoulFireAPI.createInstance(name: name)
            await loadInstances()
            return id
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return nil
        }
    }

    @MainActor
    func deleteInstance(id: String) async -> Bool {
        do {
            try await SoulFireAPI.deleteInstance(id: id)
            await loadInstances()
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }
}

// MARK: - Bot 列表 VM

@Observable
final class BotsViewModel {
    var bots: [BotListEntry] = []
    var isLoading = false
    var errorMessage: String?

    // 刷新控制
    var autoRefresh = true
    private var refreshTask: Task<Void, Never>?

    let instanceId: String

    init(instanceId: String) {
        self.instanceId = instanceId
    }

    @MainActor
    func loadBots() async {
        isLoading = true
        defer { isLoading = false }
        do {
            bots = try await SoulFireAPI.listBots(instanceId: instanceId)
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        guard autoRefresh else { return }
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await self.loadBots()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// 启动/停止单个 bot
    @MainActor
    func setDesired(running: Bool, botIds: [String]) async {
        do {
            let _ = try await SoulFireAPI.setBotsDesiredState(
                instanceId: instanceId, botIds: botIds, running: running
            )
            await loadBots()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    @MainActor
    func restart(botIds: [String]) async {
        do {
            try await SoulFireAPI.restartBots(instanceId: instanceId, botIds: botIds)
            await loadBots()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    var onlineCount: Int { bots.filter { $0.isOnline ?? false }.count }
    var runningCount: Int { bots.filter(\.desiredRunning).count }
}
