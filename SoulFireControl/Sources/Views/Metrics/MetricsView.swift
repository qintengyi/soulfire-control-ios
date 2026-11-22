import SwiftUI

// MARK: - 指标页 (实例指标 + 服务器指标)

struct MetricsView: View {
    let instanceId: String

    @State private var vm: MetricsViewModel?

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
                let newVM = MetricsViewModel(instanceId: instanceId)
                vm = newVM
                await newVM.loadMetrics()
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: MetricsViewModel) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let error = vm.errorMessage, vm.instanceMetrics == nil {
                    ErrorStateView(message: error) {
                        Task { await vm.loadMetrics() }
                    }
                } else {
                    instanceMetricsCard(vm)
                    serverMetricsCard(vm)
                }
            }
            .padding(16)
        }
        .background(MCTheme.background)
        .navigationTitle("指标")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                RefreshButton { Task { await vm.loadMetrics() } }
            }
        }
    }

    // MARK: 实例指标

    private func instanceMetricsCard(_ vm: MetricsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("实例指标")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MCTheme.textSecondary)

            if let snapshot = vm.latestInstanceSnapshot {
                let rows: [(String, String)] = [
                    ("在线 Bot", "\(snapshot.botsOnline) / \(snapshot.botsTotal)"),
                    ("发包速率", "\(Int(snapshot.packetsSentPerSecond ?? 0)) pps"),
                    ("收包速率", "\(Int(snapshot.packetsReceivedPerSecond ?? 0)) pps"),
                    ("发送流量", ByteFormat.rate(snapshot.bytesSentPerSecond)),
                    ("接收流量", ByteFormat.rate(snapshot.bytesReceivedPerSecond)),
                    ("平均 Tick", snapshot.avgTickDurationMs.map { String(format: "%.1f ms", $0) } ?? "—"),
                    ("平均生命", snapshot.avgHealth.map { String(format: "%.1f ❤️", $0) } ?? "—"),
                    ("已加载区块", snapshot.totalLoadedChunks.map(String.init) ?? "—"),
                    ("跟踪实体", snapshot.totalTrackedEntities.map(String.init) ?? "—"),
                ]
                metricGrid(rows)
            } else {
                Text("暂无数据")
                    .font(.system(size: 12))
                    .foregroundStyle(MCTheme.textTertiary)
            }
        }
        .mcCard()
    }

    // MARK: 服务器指标

    private func serverMetricsCard(_ vm: MetricsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("服务器指标")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MCTheme.textSecondary)

            if let snapshot = vm.latestServerSnapshot {
                let cpuPercent = snapshot.processCpuLoad.map { max(0, $0) * 100 }
                let sysPercent = snapshot.systemCpuLoad.map { max(0, $0) * 100 }
                let heapUsed = Double(snapshot.heapUsedBytes ?? "")
                let heapMax = Double(snapshot.heapMaxBytes ?? "")

                let rows: [(String, String)] = [
                    ("JVM CPU", cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—"),
                    ("系统 CPU", sysPercent.map { String(format: "%.1f%%", $0) } ?? "—"),
                    ("堆内存", {
                        guard let used = heapUsed else { return "—" }
                        let maxV = (heapMax ?? 0) > 0 ? heapMax! : nil
                        if let maxV {
                            return "\(ByteFormat.format(used)) / \(ByteFormat.format(maxV))"
                        }
                        return ByteFormat.format(used)
                    }()),
                    ("线程数", snapshot.threadCount.map(String.init) ?? "—"),
                    ("运行时长", UptimeFormat.format(snapshot.uptimeMs)),
                    ("全部在线", "\(snapshot.totalBotsOnline ?? 0) / \(snapshot.totalBotsTotal ?? 0)"),
                ]
                metricGrid(rows)

                // CPU 条
                if let cpu = cpuPercent {
                    HStack(spacing: 8) {
                        Text("CPU")
                            .font(.system(size: 11))
                            .foregroundStyle(MCTheme.textTertiary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(MCTheme.backgroundElevated)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cpu > 80 ? MCTheme.redstone : (cpu > 50 ? MCTheme.gold : MCTheme.emerald))
                                    .frame(width: geo.size.width * min(cpu / 100, 1))
                            }
                        }
                        .frame(height: 8)
                        Text(String(format: "%.0f%%", cpu))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(MCTheme.textSecondary)
                    }
                }
            } else {
                Text("暂无数据")
                    .font(.system(size: 12))
                    .foregroundStyle(MCTheme.textTertiary)
            }
        }
        .mcCard()
    }

    private func metricGrid(_ rows: [(String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
            ForEach(0..<rows.count, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text(rows[i].0)
                        .font(.system(size: 11))
                        .foregroundStyle(MCTheme.textTertiary)
                    Text(rows[i].1)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(MCTheme.textPrimary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
