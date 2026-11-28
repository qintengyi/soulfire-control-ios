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

    /// 方向键按下/松开 — 只发送该字段, 不覆盖其他状态 (如潜行/疾跑)
    /// SoulFire movement:set 是部分更新: 只发送非 nil 字段, 其他字段保持原值
    @MainActor
    func setMovement(axis: MovementAxis, active: Bool) {
        // 同步本地状态
        switch axis {
        case .forward: movement.forward = active
        case .backward: movement.backward = active
        case .left: movement.left = active
        case .right: movement.right = active
        case .jump: movement.jumping = active
        case .sneak: movement.sneaking = active
        case .sprint: movement.sprinting = active
        }
        // 只发送被改变的字段 (其他字段为 nil, 服务端保持原值)
        sendAxisMovement(axis, value: active)
    }

    /// 发送单个轴的字段更新 (其他字段为 nil, 不影响已有状态)
    @MainActor
    private func sendAxisMovement(_ axis: MovementAxis, value: Bool) {
        let req: SetMovementStateRequest
        switch axis {
        case .forward:  req = SetMovementStateRequest(forward: value)
        case .backward: req = SetMovementStateRequest(backward: value)
        case .left:     req = SetMovementStateRequest(left: value)
        case .right:    req = SetMovementStateRequest(right: value)
        case .jump:     req = SetMovementStateRequest(jumping: value)
        case .sneak:    req = SetMovementStateRequest(sneaking: value)
        case .sprint:   req = SetMovementStateRequest(sprinting: value)
        }
        sendMovementRequest(req)
    }

    /// 跳跃: 支持长按 (按住空格 = 持续跳跃), 点击瞬时也发送 jumping=true
    /// SoulFire OpenAPI: "When held, the bot will jump repeatedly."
    @MainActor
    func jump() {
        movement.jumping = true
        sendAxisMovement(.jump, value: true)
    }

    /// 跳跃松开 (长按松手时调用)
    @MainActor
    func endJump() {
        movement.jumping = false
        sendAxisMovement(.jump, value: false)
    }

    /// 切换潜行状态 (只发 sneaking 字段)
    @MainActor
    func toggleSneak() {
        movement.sneaking.toggle()
        sendAxisMovement(.sneak, value: movement.sneaking)
    }

    /// 切换疾跑状态 (只发 sprinting 字段)
    /// 注意: 疾跑需要 forward 移动 + 饥饿值 >= 6, 否则服务端会忽略
    @MainActor
    func toggleSprint() {
        movement.sprinting.toggle()
        sendAxisMovement(.sprint, value: movement.sprinting)
    }

    /// 统一发送部分更新请求
    @MainActor
    private func sendMovementRequest(_ request: SetMovementStateRequest) {
        let instanceId = self.instanceId
        let botId = self.botId
        Task {
            do {
                _ = try await SoulFireAPI.setMovement(instanceId: instanceId, botId: botId, request: request)
            } catch {
                // 静默失败, 移动控制不应弹出错误打断用户
            }
        }
    }

    @MainActor
    func resetMovement() async {
        movement = MovementState()
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

    /// 丢弃指定槽位的全部物品 (DROP_ALL)
    @MainActor
    func dropSlot(_ slot: Int) async {
        do {
            let resp = try await SoulFireAPI.clickInventorySlot(
                instanceId: instanceId, botId: botId, slot: slot, clickType: "DROP_ALL"
            )
            if !resp.success {
                actionMessage = resp.error ?? "丢弃失败"
            } else {
                actionMessage = "已丢弃"
            }
            await loadInventory()
        } catch {
            actionMessage = "丢弃失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }

    /// 一键丢弃背包内所有物品 (遍历每个有物品的槽位调用 DROP_ALL)
    @MainActor
    func dropAllItems() async {
        guard let inventory = inventory else {
            actionMessage = "背包未加载"
            return
        }
        let slotsToDrop = inventory.slots.filter { $0.count > 0 }.map { $0.slot }
        guard !slotsToDrop.isEmpty else {
            actionMessage = "背包为空, 无可丢弃物品"
            return
        }
        actionMessage = "正在丢弃 \(slotsToDrop.count) 个槽位物品…"
        var failed = 0
        for slot in slotsToDrop {
            do {
                let resp = try await SoulFireAPI.clickInventorySlot(
                    instanceId: instanceId, botId: botId, slot: slot, clickType: "DROP_ALL"
                )
                if !resp.success { failed += 1 }
            } catch {
                failed += 1
            }
        }
        await loadInventory()
        actionMessage = failed == 0
            ? "已丢弃全部 \(slotsToDrop.count) 个槽位物品"
            : "丢弃完成, \(failed) 个失败"
    }
}

enum MovementAxis: CaseIterable {
    case forward, backward, left, right, jump, sneak, sprint
}
