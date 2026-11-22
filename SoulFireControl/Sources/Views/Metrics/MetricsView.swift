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
                MetricGrid(rows: rows)
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
                ServerMetricsContent(snapshot: snapshot)
            } else {
                Text("暂无数据")
                    .font(.system(size: 12))
                    .foregroundStyle(MCTheme.textTertiary)
            }
        }
        .mcCard()
    }
}

// MARK: - CPU 进度条 (独立子视图, 避免类型推断超时)

struct CPUBarView: View {
    let cpu: Double

    private var barColor: Color {
        cpu > 80 ? MCTheme.redstone : (cpu > 50 ? MCTheme.gold : MCTheme.emerald)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cpuHeader
            cpuBar
        }
    }

    private var cpuHeader: some View {
        HStack {
            Text("CPU 占用")
                .font(.system(size: 11))
                .foregroundStyle(MCTheme.textTertiary)
            Spacer()
            Text(String(format: "%.0f%%", cpu))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(barColor)
        }
    }

    private var cpuBar: some View {
        GeometryReader { geo in
            cpuBarContent(width: geo.size.width)
        }
        .frame(height: 6)
    }

    private func cpuBarContent(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(MCTheme.backgroundElevated)
            Capsule()
                .fill(barColor.opacity(0.85))
                .frame(width: max(0, width * min(cpu / 100, 1)))
        }
    }
}

// MARK: - 服务器指标内容 (独立子视图, 避免类型推断超时)

struct ServerMetricsContent: View {
    let snapshot: ServerMetricsSnapshot

    private var cpuPercent: Double? {
        snapshot.processCpuLoad.map { max(0, $0) * 100 }
    }

    private var sysPercent: Double? {
        snapshot.systemCpuLoad.map { max(0, $0) * 100 }
    }

    private var rows: [(String, String)] {
        let heapUsed = Double(snapshot.heapUsedBytes ?? "")
        let heapMax = Double(snapshot.heapMaxBytes ?? "")
        var heapStr = "—"
        if let used = heapUsed {
            if let maxV = heapMax, maxV > 0 {
                heapStr = "\(ByteFormat.format(used)) / \(ByteFormat.format(maxV))"
            } else {
                heapStr = ByteFormat.format(used)
            }
        }
        return [
            ("JVM CPU", cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—"),
            ("系统 CPU", sysPercent.map { String(format: "%.1f%%", $0) } ?? "—"),
            ("堆内存", heapStr),
            ("线程数", snapshot.threadCount.map(String.init) ?? "—"),
            ("运行时长", UptimeFormat.format(snapshot.uptimeMs)),
            ("全部在线", "\(snapshot.totalBotsOnline ?? 0) / \(snapshot.totalBotsTotal ?? 0)"),
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            MetricGrid(rows: rows)
            if let cpu = cpuPercent {
                CPUBarView(cpu: cpu)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - 指标网格 (独立子视图)

struct MetricGrid: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<pairCount, id: \.self) { i in
                gridRow(i)
            }
        }
    }

    private var pairCount: Int {
        (rows.count + 1) / 2
    }

    @ViewBuilder
    private func gridRow(_ i: Int) -> some View {
        HStack(spacing: 0) {
            MetricCell(row: rows[i * 2])
            if i * 2 + 1 < rows.count {
                MetricCell(row: rows[i * 2 + 1])
            } else {
                Color.clear
            }
        }
        if i < pairCount - 1 {
            Divider()
                .background(MCTheme.surfaceRaised.opacity(0.5))
                .padding(.horizontal, 8)
        }
    }
}

struct MetricCell: View {
    let row: (String, String)

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.0)
                .font(.system(size: 11))
                .foregroundStyle(MCTheme.textTertiary)
            Text(row.1)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(MCTheme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
}
