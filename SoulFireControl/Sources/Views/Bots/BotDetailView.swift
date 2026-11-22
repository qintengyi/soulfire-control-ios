import SwiftUI
import UIKit

// MARK: - Bot 详情控制台

struct BotDetailView: View {
    @Environment(AppViewModel.self) private var appVM
    let instanceId: String
    let bot: BotListEntry

    @State private var vm: BotDetailViewModel?
    @State private var showInventorySheet = false

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInventorySheet = true
                    // 进入 sheet 时若背包未加载则自动拉一次
                    if let vm, vm.inventory == nil {
                        Task { await vm.loadInventory() }
                    }
                } label: {
                    Image(systemName: "backpack.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MCTheme.diamond)
                }
            }
        }
        .sheet(isPresented: $showInventorySheet) {
            if let vm {
                InventorySheet(vm: vm)
            }
        }
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

                // 背包入口 (大按钮, 点击弹出 sheet)
                inventoryEntryButton(vm)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .refreshable { await vm.loadBot() }
    }

    // MARK: 背包入口按钮 (醒目)

    private func inventoryEntryButton(_ vm: BotDetailViewModel) -> some View {
        Button {
            showInventorySheet = true
            if vm.inventory == nil {
                Task { await vm.loadInventory() }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: MCTheme.cornerRadiusSmall, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [MCTheme.diamond.opacity(0.25), MCTheme.diamond.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: MCTheme.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(MCTheme.diamond.opacity(0.5), lineWidth: 0.5)
                        )
                    Image(systemName: "backpack.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MCTheme.diamond)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("背包 / 物品栏")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MCTheme.textPrimary)
                    Text(inventorySubtitle(vm))
                        .font(.system(size: 12))
                        .foregroundStyle(MCTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MCTheme.textTertiary)
            }
            .mcCard(padding: 14)
            .contentShape(RoundedRectangle(cornerRadius: MCTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    private func inventorySubtitle(_ vm: BotDetailViewModel) -> String {
        if vm.isLoadingInventory { return "正在加载…" }
        if let inv = vm.inventory {
            let total = inv.slots.reduce(0) { $0 + $1.count }
            return "\(inv.slots.count) 种物品 · 共 \(total) 件"
        }
        return "点击查看 Bot 背包"
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
        .frame(width: 72, height: 56)
        .background(
            RoundedRectangle(cornerRadius: MCTheme.cornerRadiusSmall, style: .continuous)
                .fill(isActive ? MCTheme.redstone.opacity(0.9) : MCTheme.backgroundElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: MCTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(isActive ? 0.2 : 0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: isActive ? MCTheme.redstone.opacity(0.3) : .clear, radius: 6, y: 2)
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
                        Capsule().fill(isActive ? MCTheme.gold.opacity(0.9) : MCTheme.backgroundElevated.opacity(0.6))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(isActive ? 0.2 : 0.06), lineWidth: 0.5))
                            .shadow(color: isActive ? MCTheme.gold.opacity(0.3) : .clear, radius: 4, y: 1)
                    )
        }
        .buttonStyle(.plain)
    }

    // MARK: 聊天/命令

    @ViewBuilder
    private func chatCard(_ vm: BotDetailViewModel) -> some View {
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
                quickAction("飞行", vm.isFlying ? "checkmark.circle.fill" : "wing.raise", vm.isFlying ? MCTheme.emerald : MCTheme.diamond) {
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

    // MARK: 背包入口与 Sheet 已移至下方独立实现
}

// MARK: - 背包 Sheet (完整背包界面)

struct InventorySheet: View {
    let vm: BotDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if vm.isLoadingInventory && vm.inventory == nil {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(MCTheme.diamond)
                                .controlSize(.large)
                            Text("正在加载背包…")
                                .font(.system(size: 13))
                                .foregroundStyle(MCTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if let inventory = vm.inventory {
                        InventoryGrid(
                            inventory: inventory,
                            onSlotClick: { slot in Task { await vm.clickSlot(slot) } }
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "backpack")
                                .font(.system(size: 44))
                                .foregroundStyle(MCTheme.textTertiary)
                            Text("暂无背包数据")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MCTheme.textSecondary)
                            Text("Bot 需在线才能读取背包")
                                .font(.system(size: 12))
                                .foregroundStyle(MCTheme.textTertiary)
                            Button {
                                Task { await vm.loadInventory() }
                            } label: {
                                Label("重新加载", systemImage: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(MCTheme.diamond)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(MCTheme.diamond.opacity(0.12))
                                            .overlay(Capsule().strokeBorder(MCTheme.diamond.opacity(0.4), lineWidth: 0.5))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(MCTheme.background.ignoresSafeArea())
            .navigationTitle("背包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(MCTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.loadInventory() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MCTheme.diamond)
                    }
                    .disabled(vm.isLoadingInventory)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(MCTheme.background)
    }
}

// MARK: - 背包网格

struct InventoryGrid: View {
    let inventory: BotInventoryStateResponse
    var onSlotClick: (Int) -> Void

    /// 按 region 渲染每个区域
    var body: some View {
        VStack(spacing: 12) {
            ForEach(inventory.layout.regions ?? [], id: \.id) { region in
                VStack(alignment: .leading, spacing: 6) {
                    Text(region.label ?? region.id ?? "—")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MCTheme.textTertiary)
                    slotGrid(region)
                }
            }
            // 手持物品
            if let carried = inventory.carriedItem {
                HStack(spacing: 8) {
                    Text("手持")
                        .font(.system(size: 11))
                        .foregroundStyle(MCTheme.textTertiary)
                    slotView(carried, clickable: false)
                    Text("\(carried.count)x \(carried.shortItemName)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(MCTheme.textPrimary)
                    Spacer()
                }
                .padding(.top, 2)
            }
            // 物品列表
            if !inventory.slots.isEmpty {
                Divider().background(MCTheme.surfaceRaised.opacity(0.5))
                VStack(alignment: .leading, spacing: 4) {
                    Text("物品清单")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MCTheme.textTertiary)
                    ForEach(inventory.slots, id: \.slot) { slot in
                        HStack {
                            Text(slot.shortItemName)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(MCTheme.textPrimary)
                            Spacer()
                            Text("x\(slot.count)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MCTheme.diamond)
                        }
                    }
                }
            }
        }
    }

    private func slotGrid(_ region: SlotRegion) -> some View {
        let columns = max(region.columns ?? 1, 1)
        let slotCount = region.slotCount ?? 0
        let rows = slotCount > 0 ? (slotCount + columns - 1) / columns : 0
        let itemMap = Dictionary(uniqueKeysWithValues: inventory.slots.map { ($0.slot, $0) })
        let start = region.startIndex ?? 0

        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { col in
                        let slotIndex = start + row * columns + col
                        if slotIndex < start + slotCount {
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
                ZStack {
                    RoundedRectangle(cornerRadius: MCTheme.cornerRadiusTiny, style: .continuous)
                        .fill(slotFill(for: item))
                        .frame(width: 36, height: 36)
                    // 物品图标 (如果有 base64 图标)
                    if let iconData = item.iconBase64,
                       let uiImage = UIImage(data: Data(base64Encoded: iconData) ?? Data()) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    } else {
                        // 无图标时显示物品名首字母
                        Text(String(item.shortItemName.prefix(3)))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(MCTheme.textSecondary)
                            .lineLimit(1)
                    }
                    // 数量 (右下角)
                    if item.count > 1 {
                        Text("\(item.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(2)
                            .shadow(color: .black, radius: 1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: MCTheme.cornerRadiusTiny, style: .continuous)
                        .strokeBorder(MCTheme.surfaceRaised.opacity(0.6), lineWidth: 0.5)
                )
            } else {
                RoundedRectangle(cornerRadius: MCTheme.cornerRadiusTiny, style: .continuous)
                    .fill(MCTheme.backgroundElevated.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: MCTheme.cornerRadiusTiny, style: .continuous)
                            .strokeBorder(MCTheme.surfaceRaised.opacity(0.4), lineWidth: 0.5)
                    )
            }
        }
        .onTapGesture {
            if clickable, let item { onSlotClick(item.slot) }
        }
    }

    private func slotFill(for item: InventorySlot) -> Color {
        if item.iconBase64 != nil {
            return MCTheme.surfaceRaised.opacity(0.8)
        }
        return MCTheme.surface
    }
}
