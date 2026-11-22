import Foundation

// MARK: - 客户端数据 (当前用户 + 服务器版本信息)

struct ClientDataResponse: Codable, Sendable {
    let id: String
    let username: String
    /// SoulFire 2.10+ 不再返回 role, 改用 serverPermissions 数组; 保留为可选兼容旧版
    let role: String?
    let email: String?
    let serverInfo: ServerInfo
    let serverPermissions: [ServerPermission]?
}

/// 服务端权限项 (granted + 可选的 globalPermission 名称)
struct ServerPermission: Codable, Sendable {
    let globalPermission: String?
    let granted: Bool
}

// MARK: - 服务器信息

struct ServerInfo: Codable, Sendable {
    let version: String
    let commitHash: String
    let branchName: String
    let publicApiAddress: String
    let publicWebdavAddress: String
    let publicDocsAddress: String
    let publicMcpAddress: String
    let minecraftVersion: String
}

// MARK: - 实例

struct InstanceListResponse: Codable, Sendable {
    let instances: [InstanceSummary]
}

struct InstanceSummary: Codable, Sendable, Identifiable {
    let id: String
    let friendlyName: String
    let icon: String?
    let botSummary: BotFleetSummary?
}

struct BotFleetSummary: Codable, Sendable {
    /// SoulFire 2.10+ 在新建实例尚未启动任何 bot 时, botSummary 直接返回 {} 空对象
    /// 因此全部字段都改可选, 使用处用 ?? 0 兜底
    let totalBots: Int?
    let desiredBots: Int?
    let onlineBots: Int?
    let startingBots: Int?
    let retryingBots: Int?
    let failedBots: Int?
}

struct InstanceInfoResponse: Codable, Sendable {
    let info: InstanceInfo?
}

struct InstanceInfo: Codable, Sendable {
    let friendlyName: String
    let icon: String?
    let config: InstanceConfig
    let lastModified: String?
}

struct InstanceConfig: Codable, Sendable {
    let settings: [SettingsNamespace]?
    let accounts: [MinecraftAccount]?
    let proxies: [Proxy]?
}

struct InstanceCreateResponse: Codable, Sendable {
    let id: String
}

// MARK: - 设置命名空间 (protobuf Value 宽松解析)

struct SettingsNamespace: Codable, Sendable {
    let namespace: String
    let entries: [SettingsEntry]?
}

struct SettingsEntry: Codable, Sendable {
    let key: String
    let value: JSONValue?
}

/// 宽松 JSON Value — protobuf google.protobuf.Value 的任意类型
enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSONValue")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let b): try container.encode(b)
        case .number(let n): try container.encode(n)
        case .string(let s): try container.encode(s)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        }
    }

    var displayString: String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n):
            if n == n.rounded() && abs(n) < 1e15 { return String(Int64(n)) }
            return String(n)
        case .string(let s): return s
        case .array: return "[…]"
        case .object: return "{…}"
        }
    }
}

// MARK: - Minecraft 账号

struct MinecraftAccount: Codable, Sendable, Identifiable {
    let type: String
    let profileId: String
    let lastKnownName: String?
    let config: [SettingsNamespace]?

    var id: String { profileId }
}

struct AddAccountRequest: Codable, Sendable {
    let account: MinecraftAccount
}

struct BatchAddAccountsRequest: Codable, Sendable {
    let accounts: [MinecraftAccount]
}

struct BatchRemoveAccountsRequest: Codable, Sendable {
    let profileIds: [String]
}

// MARK: - 代理

enum ProxyType: String, Codable, Sendable, CaseIterable {
    case http = "HTTP"
    case socks4 = "SOCKS4"
    case socks5 = "SOCKS5"
}

struct Proxy: Codable, Sendable, Identifiable {
    let type: String
    let address: String
    let username: String?
    let password: String?

    var id: String { address }
    var proxyType: ProxyType { ProxyType(rawValue: type) ?? .http }
}

struct AddProxyRequest: Codable, Sendable {
    let proxy: Proxy
}

struct BatchAddProxiesRequest: Codable, Sendable {
    let proxies: [Proxy]
}

struct UpdateProxyRequest: Codable, Sendable {
    let proxy: Proxy
}

// MARK: - Bot

struct BotListResponse: Codable, Sendable {
    let bots: [BotListEntry]
}

struct BotListEntry: Codable, Sendable, Identifiable, Hashable {
    let profileId: String
    /// SoulFire 2.10+ 对离线 bot 省略此字段, 改可选
    let isOnline: Bool?
    let liveState: BotLiveState?
    let pingMs: Int?
    let connectionPhase: String
    let accountName: String?
    let status: BotStatus

    var id: String { profileId }

    static func == (lhs: BotListEntry, rhs: BotListEntry) -> Bool {
        lhs.profileId == rhs.profileId && lhs.status.updatedAt == rhs.status.updatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(profileId)
    }
}

struct BotStatus: Codable, Sendable {
    let profileId: String
    let desiredState: String
    let runtimeState: String
    let lastError: String?
    let updatedAt: String
}

struct BotInfoResponse: Codable, Sendable {
    let liveState: BotLiveState?
    let status: BotStatus?
}

struct BotLiveState: Codable, Sendable {
    let x: Double?
    let y: Double?
    let z: Double?
    let xRot: Double?
    let yRot: Double?
    let health: Double?
    let maxHealth: Double?
    let foodLevel: Int?
    let saturationLevel: Double?
    let inventory: [InventorySlot]?
    let selectedHotbarSlot: Int?
    let dimension: String?
    let experienceLevel: Int?
    let experienceProgress: Double?
    let skinTextureHash: String?
    let gameMode: String?
}

// MARK: - 背包

struct BotInventoryStateResponse: Codable, Sendable {
    let layout: ContainerLayout
    let slots: [InventorySlot]
    /// SoulFire 在无手持物品时省略, 改可选
    let carriedItem: InventorySlot?
    /// SoulFire 在未选中快捷栏时省略, 改可选
    let selectedHotbarSlot: Int?
}

struct ContainerLayout: Codable, Sendable {
    let title: String?
    let regions: [SlotRegion]?
    let totalSlots: Int?
    let containerType: String?
}

struct SlotRegion: Codable, Sendable {
    let id: String?
    let label: String?
    /// SoulFire 对单槽位 region (如 crafting_output) 省略此字段, 改可选
    let startIndex: Int?
    let slotCount: Int?
    let columns: Int?
    /// SoulFire 对部分 region 省略此字段, 改可选
    let type: String?
}

struct InventorySlot: Codable, Sendable, Identifiable {
    let slot: Int
    let itemId: String
    let count: Int
    let displayName: String?
    let iconBase64: String?
    let iconMimeType: String?

    var id: Int { slot }

    /// 物品简名 (去掉 minecraft: 前缀)
    var shortItemName: String {
        itemId.replacingOccurrences(of: "minecraft:", with: "")
    }
}

struct BotInventoryClickResponse: Codable, Sendable {
    let success: Bool
    let error: String?
}

// MARK: - 操作请求体

struct SetBotsDesiredStateRequest: Codable, Sendable {
    let botIds: [String]
    let desiredState: String
}

struct RestartBotsRequest: Codable, Sendable {
    let botIds: [String]
}

struct SendChatRequest: Codable, Sendable {
    let message: String
}

struct SetRotationRequest: Codable, Sendable {
    let yaw: Double
    let pitch: Double
}

struct SetMovementStateRequest: Codable, Sendable {
    var forward: Bool?
    var backward: Bool?
    var left: Bool?
    var right: Bool?
    var jumping: Bool?
    var sneaking: Bool?
    var sprinting: Bool?
}

struct SetFlyingRequest: Codable, Sendable {
    let flying: Bool
}

struct BotActionResult: Codable, Sendable {
    let success: Bool?
    let error: String?
}

struct SendChatResponse: Codable, Sendable {
    let result: BotActionResult?
}

// MARK: - 指令

struct CommandScope: Codable, Sendable {
    var global: EmptyObject?
    var instance: InstanceRef?
    var bot: BotRef?

    static func instanceScope(_ id: String) -> CommandScope {
        CommandScope(global: nil, instance: InstanceRef(instanceId: id), bot: nil)
    }

    static func botScope(instanceId: String, botId: String) -> CommandScope {
        CommandScope(global: nil, instance: nil, bot: BotRef(instanceId: instanceId, botId: botId))
    }
}

struct EmptyObject: Codable, Sendable {}

struct InstanceRef: Codable, Sendable {
    let instanceId: String
}

struct BotRef: Codable, Sendable {
    let instanceId: String
    let botId: String
}

struct ExecuteCommandRequest: Codable, Sendable {
    let scope: CommandScope
    let command: String
}

struct CommandResponse: Codable, Sendable {
    let code: Int
}

// MARK: - 日志

struct PreviousLogResponse: Codable, Sendable {
    let messages: [LogEntry]
}

struct LogEntry: Codable, Sendable, Identifiable {
    let id: String
    let message: String
    let instanceId: String?
    let botAccountId: String?
    let scriptId: String?
    let personal: Bool?
    let instanceName: String?
    let botAccountName: String?
    let timestamp: String?
    let loggerName: String?
    let level: String?
}

struct GetPreviousLogsRequest: Codable, Sendable {
    let scope: LogScope
    let count: Int
}

struct LogScope: Codable, Sendable {
    var global: EmptyObject?
    var instance: InstanceRef?
    var bot: BotRef?

    static func instanceScope(_ id: String) -> LogScope {
        LogScope(global: nil, instance: InstanceRef(instanceId: id), bot: nil)
    }

    static func botScope(instanceId: String, botId: String) -> LogScope {
        LogScope(global: nil, instance: nil, bot: BotRef(instanceId: instanceId, botId: botId))
    }
}

// MARK: - 指标

struct GetInstanceMetricsResponse: Codable, Sendable {
    let snapshots: [MetricsSnapshot]
    let distributions: MetricsDistributions?
}

struct GetServerMetricsResponse: Codable, Sendable {
    let snapshots: [ServerMetricsSnapshot]
}

struct MetricsSnapshot: Codable, Sendable {
    let timestamp: String
    let botsOnline: Int?
    let botsTotal: Int?
    let packetsSentTotal: String?
    let packetsReceivedTotal: String?
    let bytesSentTotal: String?
    let bytesReceivedTotal: String?
    let packetsSentPerSecond: Double?
    let packetsReceivedPerSecond: Double?
    let bytesSentPerSecond: Double?
    let bytesReceivedPerSecond: Double?
    let avgTickDurationMs: Double?
    let maxTickDurationMs: Double?
    let avgHealth: Double?
    let avgFoodLevel: Double?
    let totalLoadedChunks: Int?
    let totalTrackedEntities: Int?
    let connections: Int?
    let disconnections: Int?
}

struct ServerMetricsSnapshot: Codable, Sendable {
    let timestamp: String
    let processCpuLoad: Double?
    let systemCpuLoad: Double?
    let heapUsedBytes: String?
    let heapCommittedBytes: String?
    let heapMaxBytes: String?
    let nonHeapUsedBytes: String?
    let threadCount: Int?
    let daemonThreadCount: Int?
    let uptimeMs: String?
    let availableProcessors: Int?
    let totalBotsOnline: Int?
    let totalBotsTotal: Int?
    let totalBotsDesired: Int?
}

struct MetricsDistributions: Codable, Sendable {
    let healthHistogram: [Int]?
    let foodHistogram: [Int]?
}

// MARK: - 错误

struct APIErrorBody: Codable, Sendable {
    let code: Int?
    let grpcCode: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case grpcCode = "grpc-code"
        case message
    }
}
