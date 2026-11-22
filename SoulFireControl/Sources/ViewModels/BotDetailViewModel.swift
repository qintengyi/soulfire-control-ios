import SwiftUI
import Observation

// MARK: - 单个 Bot 详情 VM (控制台)

@Observable
final class BotDetailViewModel {
    let instanceId: String
    let botId: String

    // Bot 数据
    var botInfo: BotInfoResponse?
    var liveState: BotLiveState?
    var status: BotStatus?

    // 控制面板
    var movement = MovementState()
    var chatInput = ""
    var commandInput = ""
    var isSendingChat = false

    // 背包
    var inventory: BotInventoryStateResponse?
    var isLoadingInventory = false

    var isLoading = false
    var errorMessage: String?
    var actionMessage: String?

    // 移动节流
    private var lastMovementSent: MovementState = MovementState()
    private var movementSendTask: Task<Void, Never>?

    init(instanceId: String, botId: String) {
        self.instanceId = instanceId
        self.botId = botId
    }

    @MainActor
    func loadBot() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await SoulFireAPI.getBotInfo(instanceId: instanceId, botId: botId)
            botInfo = info
            liveState = info.liveState
            status = info.status
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func startAutoRefresh() {
        Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { break }
                await self.loadBot()
            }
        }
    }

    // MARK: 聊天/命令

    @MainActor
    func sendChat() async {
        let msg = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        isSendingChat = true
        defer { isSendingChat = false }
        do {
            try await SoulFireAPI.sendChat(instanceId: instanceId, botId: botId, message: msg)
            chatInput = ""
            actionMessage = "已发送"
        } catch {
            actionMessage = "发送失败：\((error as? APIError)?.localizedDescription ?? error.localizedDescription)"
        }
    }

    @MainActor
    func executeCommand() async {
        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        do {
            let code = try await SoulFireAPI.executeCommand(
                scope: .botScope(instanceId: instanceId, botId: botId),
                command: cmd
            )
            commandInput = ""
            actionMessage = code == 1 ? "命令执行成功" : "命令返回码: \(code)"
        } catch {
            actionMessage = "命令失败：\((error as? APIError)?.localizedDescription ?? error.localizedDescription)"
        }
    }

    // MARK: 移动控制

    /// 方向键按下/松开
    @MainActor
    func setMovement(axis: MovementAxis, active: Bool) {
        switch axis {
        case .forward: movement.forward = active
        case .backward: movement.backward = active
        case .left: movement.left = active
        case .right: movement.right = active
        case .jump: movement.jumping = active
        case .sneak: movement.sneaking = active
        case .sprint: movement.sprinting = active
        }
        sendMovementIfNeeded()
    }

    private func sendMovementIfNeeded() {
        // 500ms 节流: 只有状态变化才发送
        guard movement != lastMovementSent else { return }
        lastMovementSent = movement
        let state = movement
        let instanceId = self.instanceId
        let botId = self.botId
        movementSendTask?.cancel()
        movementSendTask = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            do {
                try await SoulFireAPI.setMovement(instanceId: instanceId, botId: botId, state: state)
            } catch {
                // 静默失败，控制类操作由 UI 重试
            }
        }
    }

    @MainActor
    func resetMovement() async {
        movement = MovementState()
        lastMovementSent = movement
        do {
            try await SoulFireAPI.resetMovement(instanceId: instanceId, botId: botId)
            actionMessage = "已重置移动"
        } catch {
            actionMessage = "重置失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }

    // MARK: 视角

    @MainActor
    func setRotation(yaw: Double, pitch: Double) async {
        do {
            try await SoulFireAPI.setRotation(instanceId: instanceId, botId: botId, yaw: yaw, pitch: pitch)
        } catch {
            // 静默
        }
    }

    // MARK: 其他操作

    @MainActor
    func respawn() async {
        do {
            try await SoulFireAPI.respawn(instanceId: instanceId, botId: botId)
            actionMessage = "已重生"
            await loadBot()
        } catch {
            actionMessage = "重生失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }

    @MainActor
    func toggleFlying() async {
        let wantFly = !(liveState?.gameMode == "GAME_MODE_CREATIVE") // 简单提示用
        _ = wantFly
        do {
            try await SoulFireAPI.setFlying(instanceId: instanceId, botId: botId, flying: true)
            actionMessage = "已请求飞行"
        } catch {
            actionMessage = "失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }

    @MainActor
    func selectHotbar(_ slot: Int) async {
        do {
            try await SoulFireAPI.selectHotbarSlot(instanceId: instanceId, botId: botId, slot: slot)
            await loadBot()
        } catch {
            actionMessage = "切换失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }

    // MARK: 背包

    @MainActor
    func loadInventory() async {
        isLoadingInventory = true
        defer { isLoadingInventory = false }
        do {
            inventory = try await SoulFireAPI.getInventory(instanceId: instanceId, botId: botId)
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    @MainActor
    func clickSlot(_ slot: Int, clickType: String = "LEFT_CLICK") async {
        do {
            let resp = try await SoulFireAPI.clickInventorySlot(
                instanceId: instanceId, botId: botId, slot: slot, clickType: clickType
            )
            if !resp.success {
                actionMessage = resp.error ?? "点击失败"
            }
            await loadInventory()
        } catch {
            actionMessage = "点击失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }
}

enum MovementAxis: CaseIterable {
    case forward, backward, left, right, jump, sneak, sprint
}
