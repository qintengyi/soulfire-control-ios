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
            // Bot 在线且背包未加载时自动加载; Bot 离线时清理陈旧背包
            if info.liveState != nil {
                if inventory == nil {
                    await loadInventory()
                }
            } else {
                inventory = nil
            }
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

    // 视角/飞行状态 (服务端 liveState 不返回 flying, 本地记忆上次请求)
    var isFlying = false

    @MainActor
    func toggleFlying() async {
        let wantFly = !isFlying
        do {
            try await SoulFireAPI.setFlying(instanceId: instanceId, botId: botId, flying: wantFly)
            isFlying = wantFly
            actionMessage = wantFly ? "已请求开启飞行" : "已请求关闭飞行"
        } catch {
            actionMessage = "飞行切换失败：\((error as? APIError)?.localizedDescription ?? "")"
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

    @MainActor
    func setDesiredState(running: Bool) async {
        do {
            try await SoulFireAPI.setBotsDesiredState(
                instanceId: instanceId, botIds: [botId], running: running
            )
            actionMessage = running ? "已请求启动" : "已请求停止"
            await loadBot()
        } catch {
            actionMessage = "操作失败：\((error as? APIError)?.localizedDescription ?? "")"
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
    func clickSlot(_ slot: Int, clickType: String = "CLICK_TYPE_LEFT_CLICK") async {
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
