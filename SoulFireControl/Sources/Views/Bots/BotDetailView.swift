import SwiftUI

// MARK: - Bot 详情控制台

struct BotDetailView: View {
    @Environment(AppViewModel.self) private var appVM
    let instanceId: String
    let bot: BotListEntry

    @State private var vm: BotDetailViewModel?

    var body: some View {
        Group {
            if let vm {
                detailContent(vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(bot.accountName ?? "Bot")
        .navigationBarTitleDisplayMode(.inline)
        .background(MCTheme.background.ignoresSafeArea())
        .task {
            if vm == nil {
                let newVM = BotDetailViewModel(instanceId: instanceId, botId: bot.profileId)
                vm = newVM
                await newVM.loadBot()
                newVM.startAutoRefresh()
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ vm: BotDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // 状态卡
                statusCard(vm)

                // 操作提示
                if let msg = vm.actionMessage {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(MCTheme.diamond)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 控制板
                controlPad(vm)

                // 聊天 & 命令
                chatCard(vm)

                // 快捷操作
                quickActions(vm)

                // 背包
                inventoryCard(vm)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .refreshable { await vm.loadBot() }
    }

    // MARK: 状态卡

    private func statusCard(_ vm: BotDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("实时状态")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MCTheme.textSecondary)
                Spacer()
                if let status = vm.status {
                    StatusBadge(status.runtimeStateDisplay, runtimeColor(status.runtimeState))
                }
            }

            if let live = vm.liveState {
                let cols: [(String, String)] = [
                    ("坐标", live.x.map { String(format: "%.0f, %.0f, %.0f", $0, live.y ?? 0, live.z ?? 0) } ?? "—"),
                    ("朝向", live.yRot != nil ? String(format: "yaw %.0f / pitch %.0f", live.yRot ?? 0, live.xRot ?? 0) : "—"),
                    ("生命", live.health.map { String(format: "%.1f / %.1f", $0, live.maxHealth ?? 20) } ?? "—"),
                    ("饥饿", live.foodLevel.map(String.init) ?? "—"),
                    ("经验", live.experienceLevel.map { "Lv.\($0)" } ?? "—"),
                    ("模式", gameModeDisplay(live.gameMode)),
                    ("维度", dimensionDisplay(live.dimension)),
                ]
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    ForEach(0..<cols.count, id: \.self) { i in
                        GridRow {
                            Text(cols[i].0)
                                .font(.system(size: 12))
                                .foregroundStyle(MCTheme.textTertiary)
                                .frame(width: 42, alignment: .leading)
                            Text(cols[i].1)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(MCTheme.textPrimary)
                                .textSelection(.enabled)
                        }
                    }
                }
            } else {
                Text("Bot 离线或尚未出生，等待数据…")
                    .font(.system(size: 12))
                    .foregroundStyle(MCTheme.textTertiary)
            }

            if let err = vm.status?.lastError {
                Text("最近错误: \(err)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(MCTheme.failed)
                    .lineLimit(3)
            }
        }
        .mcCard()
    }

    private func runtimeColor(_ state: String) -> Color {
        switch state {
        case "BOT_RUNTIME_STATE_RUNNING": return MCTheme.online
        case "BOT_RUNTIME_STATE_STARTING", "BOT_RUNTIME_STATE_QUEUED": return MCTheme.connecting
        case "BOT_RUNTIME_STATE_RETRYING": return MCTheme.retrying
        case "BOT_RUNTIME_STATE_FAILED": return MCTheme.failed
        default: return MCTheme.stopped
        }
    }

    private func gameModeDisplay(_ raw: String?) -> String {
        switch raw {
        case "GAME_MODE_SURVIVAL": return "生存"
        case "GAME_MODE_CREATIVE": return "创造"
        case "GAME_MODE_ADVENTURE": return "冒险"
        case "GAME_MODE_SPECTATOR": return "观察"
        default: return "—"
        }
    }

    private func dimensionDisplay(_ raw: String?) -> String {
        switch raw {
        case "minecraft:overworld": return "主世界"
        case "minecraft:the_nether": return "下界"
        case "minecraft:the_end": return "末地"
        default: return raw ?? "—"
        }
    }

    // MARK: 十字移动控制板

    private func controlPad(_ vm: BotDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("移动控制")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MCTheme.textSecondary)
                Spacer()
                Button("重置") {
                    Task { await vm.resetMovement() }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MCTheme.gold)
                .buttonStyle(.plain)
            }

            // 十字方向键
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Spacer()
                    padButton(vm, .forward, "arrow.up", "前")
                    Spacer()
                }
                HStack(spacing: 8) {
                    padButton(vm, .left, "arrow.left", "左")
                    padButton(vm, .backward, "arrow.down", "后")
                    padButton(vm, .right, "arrow.right", "右")
                }
                HStack(spacing: 8) {
                    Spacer()
                    padButton(vm, .jump, "arrowtriangle.up", "跳")
                    Spacer()
                }
            }

            // 修饰键
            HStack(spacing: 10) {
                modifierToggle(vm, .sneak, "潜行")
                modifierToggle(vm, .sprint, "疾跑")
                Spacer()
            }
        }
        .mcCard()
    }

    private func padButton(_ vm: BotDetailViewModel, _ axis: MovementAxis, _ icon: String, _ label: String) -> some View {
        let isActive: Bool = {
            switch axis {
            case .forward: return vm.movement.forward
            case .backward: return vm.movement.backward
            case .left: return vm.movement.left
            case .right: return vm.movement.right
            case .jump: return vm.movement.jumping
            case .sneak: return vm.movement.sneaking
            case .sprint: return vm.movement.sprinting
            }
        }()

        return VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(isActive ? .white : MCTheme.textSecondary)
        .frame(width: 68, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? MCTheme.redstone : MCTheme.backgroundElevated)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(MCTheme.surfaceRaised, lineWidth: 1))
        )
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            Task { @MainActor in
                vm.setMovement(axis: axis, active: pressing)
            }
        }, perform: {})
    }

    private func modifierToggle(_ vm: BotDetailViewModel, _ axis: MovementAxis, _ label: String) -> some View {
        let isActive: Bool = {
            switch axis {
            case .sneak: return vm.movement.sneaking
            case .sprint: return vm.movement.sprinting
            default: return false
            }
        }()

        return Button {
            Task { @MainActor in
                vm.setMovement(axis: axis, active: !isActive)
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .white : MCTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isActive ? MCTheme.gold : MCTheme.backgroundElevated)
                        .overlay(Capsule().strokeBorder(MCTheme.surfaceRaised, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: 聊天/命令

    @ViewBuilder
    private func chatCard(_ vm: BotDetailViewModel) -> some View {
        let vm = self.vm ?? vm
        VStack(alignment: .leading, spacing: 10) {
            Text("聊天 / 命令")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MCTheme.textSecondary)

            HStack(spacing: 8) {
                TextField("发送聊天消息…", text: Binding(
                    get: { vm.chatInput },
                    set: { vm.chatInput = $0 }
                ))
                    .textFieldStyle(MCTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await vm.sendChat() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MCTheme.diamond)
                }
                .buttonStyle(.plain)
                .disabled(vm.chatInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack(spacing: 8) {
                TextField("执行 SoulFire 命令 (如 say hi)", text: Binding(
                    get: { vm.commandInput },
                    set: { vm.commandInput = $0 }
                ))
                    .textFieldStyle(MCTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await vm.executeCommand() }
                } label: {
                    Text("执行")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MCTheme.mcButton(MCTheme.diamond))
                }
                .buttonStyle(.plain)
                .disabled(vm.commandInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .mcCard()
    }

    // MARK: 快捷操作

    private func quickActions(_ vm: BotDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷操作")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MCTheme.textSecondary)

            HStack(spacing: 10) {
                quickAction("重生", "heart.circle.fill", MCTheme.redstone) {
                    Task { await vm.respawn() }
                }
                quickAction("飞行", "wing.raise", MCTheme.diamond) {
                    Task { await vm.toggleFlying() }
                }
            }
            HStack(spacing: 10) {
                quickAction("停止 Bot", "stop.circle.fill", MCTheme.flame) {
                    Task { await vm.setDesiredState(running: false) }
                }
                quickAction("启动 Bot", "play.circle.fill", MCTheme.emerald) {
                    Task { await vm.setDesiredState(running: true) }
                }
            }
        }
        .mcCard()
    }

    private func quickAction(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(MCTheme.mcButton(color.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }

    // MARK: 背包

    private func inventoryCard(_ vm: BotDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("背包")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MCTheme.textSecondary)
                Spacer()
                if vm.isLoadingInventory {
                    ProgressView().tint(MCTheme.diamond)
                } else {
                    RefreshButton { Task { await vm.loadInventory() } }
                }
            }

            if let inventory = vm.inventory {
                InventoryGrid(
                    inventory: inventory,
                    onSlotClick: { slot in Task { await vm.clickSlot(slot) } }
                )
            } else {
                Text("点击右上角刷新加载背包 (Bot 需在线)")
                    .font(.system(size: 12))
                    .foregroundStyle(MCTheme.textTertiary)
                    .onTapGesture { Task { await vm.loadInventory() } }
            }
        }
        .mcCard()
    }
}

// MARK: - 背包网格

struct InventoryGrid: View {
    let inventory: BotInventoryStateResponse
    var onSlotClick: (Int) -> Void

    /// 按 region 渲染每个区域
    var body: some View {
        VStack(spacing: 10) {
            ForEach(inventory.layout.regions, id: \.id) { region in
                VStack(alignment: .leading, spacing: 6) {
                    if region.slotCount > 9 || region.id.contains("container") {
                        Text(region.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MCTheme.textTertiary)
                    }
                    slotGrid(region)
                }
            }
            if let carried = inventory.carriedItem {
                HStack(spacing: 6) {
                    Text("手持")
                        .font(.system(size: 11))
                        .foregroundStyle(MCTheme.textTertiary)
                    slotView(carried, clickable: false)
                    Text("\(carried.count)x \(carried.shortItemName)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(MCTheme.textPrimary)
                }
            }
        }
    }

    private func slotGrid(_ region: SlotRegion) -> some View {
        let columns = max(region.columns, 1)
        let rows = (region.slotCount + columns - 1) / columns
        let itemMap = Dictionary(uniqueKeysWithValues: inventory.slots.map { ($0.slot, $0) })

        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { col in
                        let slotIndex = region.startIndex + row * columns + col
                        if slotIndex < region.startIndex + region.slotCount {
                            slotView(itemMap[slotIndex], clickable: true)
                        }
                    }
                }
            }
        }
    }

    private func slotView(_ item: InventorySlot?, clickable: Bool) -> some View {
        Group {
            if let item {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(slotFill(for: item))
                        .frame(width: 34, height: 34)
                    Text("\(item.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(2)
                        .shadow(color: .black, radius: 1)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(MCTheme.surfaceRaised, lineWidth: 1)
                )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(MCTheme.backgroundElevated)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(MCTheme.surfaceRaised, lineWidth: 1)
                    )
            }
        }
        .onTapGesture {
            if clickable, let item { onSlotClick(item.slot) }
        }
    }

    private func slotFill(for item: InventorySlot) -> Color {
        // 不同物品类型不同底色 (近 MC 风格)
        if item.iconBase64 != nil {
            return MCTheme.surfaceRaised
        }
        return MCTheme.surface
    }
}
