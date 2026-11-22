import Foundation

// MARK: - Bot 状态辅助

extension BotListEntry {
    /// 用户可读的运行状态
    var runtimeStateDisplay: String {
        switch status.runtimeState {
        case "BOT_RUNTIME_STATE_STOPPED": return "已停止"
        case "BOT_RUNTIME_STATE_QUEUED": return "排队中"
        case "BOT_RUNTIME_STATE_STARTING": return "启动中"
        case "BOT_RUNTIME_STATE_RUNNING": return "运行中"
        case "BOT_RUNTIME_STATE_RETRYING": return "重试中"
        case "BOT_RUNTIME_STATE_STOPPING": return "停止中"
        case "BOT_RUNTIME_STATE_FAILED": return "失败"
        default: return "未知"
        }
    }

    var desiredRunning: Bool {
        status.desiredState == "BOT_DESIRED_STATE_RUNNING"
    }

    var phaseDisplay: String {
        switch connectionPhase {
        case "BOT_CONNECTION_PHASE_CONNECTING": return "连接中"
        case "BOT_CONNECTION_PHASE_CONNECTED": return "已连接"
        case "BOT_CONNECTION_PHASE_SPAWNED": return "已出生"
        case "BOT_CONNECTION_PHASE_DIED": return "已死亡"
        case "BOT_CONNECTION_PHASE_DISCONNECTED": return "已断开"
        default: return isOnline ? "在线" : "离线"
        }
    }
}

// MARK: - 移动控制状态

/// 摇杆/按键控制的当前移动状态
struct MovementState: Codable, Equatable, Sendable {
    var forward = false
    var backward = false
    var left = false
    var right = false
    var jumping = false
    var sneaking = false
    var sprinting = false

    var anyActive: Bool {
        forward || backward || left || right || jumping || sneaking || sprinting
    }

    var toRequest: SetMovementStateRequest {
        SetMovementStateRequest(
            forward: forward,
            backward: backward,
            left: left,
            right: right,
            jumping: jumping,
            sneaking: sneaking,
            sprinting: sprinting
        )
    }
}

// MARK: - 时间格式化 (北京时间人话格式)

enum HumanTime {
    static let beijing = TimeZone(identifier: "Asia/Shanghai")!

    /// "14:23:05" 当天
    /// "昨天 14:23" 
    /// "11月18日 14:23"
    static func format(_ isoString: String?) -> String {
        guard let isoString else { return "—" }
        let parsers: [ISO8601DateFormatter] = [
            {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }(),
            {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }(),
        ]
        for parser in parsers {
            if let date = parser.date(from: isoString) {
                return humanString(date)
            }
        }
        return isoString
    }

    static func humanString(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = beijing
        let now = Date()
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let nowComps = cal.dateComponents([.year, .month, .day], from: now)

        let fmt = DateFormatter()
        fmt.timeZone = beijing
        fmt.locale = Locale(identifier: "zh_CN")

        if comps.day == nowComps.day && comps.month == nowComps.month && comps.year == nowComps.year {
            fmt.dateFormat = "HH:mm:ss"
            return fmt.string(from: date)
        }
        // 昨天
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now) {
            let yc = cal.dateComponents([.year, .month, .day], from: yesterday)
            if comps.day == yc.day && comps.month == yc.month && comps.year == yc.year {
                fmt.dateFormat = "昨天 HH:mm"
                return fmt.string(from: date)
            }
        }
        if comps.year == nowComps.year {
            fmt.dateFormat = "M月d日 HH:mm"
        } else {
            fmt.dateFormat = "yyyy年M月d日 HH:mm"
        }
        return fmt.string(from: date)
    }
}

// MARK: - 字节数格式化

enum ByteFormat {
    /// 1.2 MB / 850 KB
    static func format(_ bytes: Double?) -> String {
        guard let bytes, bytes >= 0 else { return "—" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = bytes
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(Int(value)) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    static func format(_ bytesString: String?) -> String {
        guard let bytesString, let bytes = Double(bytesString) else { return "—" }
        return format(bytes)
    }

    /// 每秒速率
    static func rate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond else { return "—" }
        return format(bytesPerSecond) + "/s"
    }
}

// MARK: - 运行时长格式化

enum UptimeFormat {
    /// "3天4小时" / "2小时15分" / "45秒"
    static func format(_ msString: String?) -> String {
        guard let msString, let ms = Double(msString), ms >= 0 else { return "—" }
        let totalSeconds = Int(ms / 1000)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if days > 0 { return "\(days)天\(hours)小时" }
        if hours > 0 { return "\(hours)小时\(minutes)分" }
        if minutes > 0 { return "\(minutes)分\(seconds)秒" }
        return "\(seconds)秒"
    }
}
