import Foundation

// MARK: - SoulFire API 门面
// 全部走 APIClient, 路径来自官方 OpenAPI 规范 (schema 2.11.0)

enum SoulFireAPI {
    private static let client = APIClient.shared

    // MARK: 服务器/客户端

    /// 获取当前用户信息和服务器版本 (用于"关于"页与连通性测试)
    static func getClientData() async throws -> ClientDataResponse {
        try await client.request("/v1/client", method: .get, as: ClientDataResponse.self)
    }

    // MARK: 实例

    static func listInstances() async throws -> [InstanceSummary] {
        let resp: InstanceListResponse = try await client.request(
            "/v1/instances", method: .get, as: InstanceListResponse.self
        )
        return resp.instances
    }

    static func createInstance(name: String) async throws -> String {
        struct CreateBody: Encodable { let friendlyName: String }
        let resp: InstanceCreateResponse = try await client.request(
            "/v1/instances", method: .post, body: CreateBody(friendlyName: name), as: InstanceCreateResponse.self
        )
        return resp.id
    }

    static func deleteInstance(id: String) async throws {
        try await client.requestEmpty("/v1/instances/\(id)", method: .delete)
    }

    static func getInstanceInfo(id: String) async throws -> InstanceInfo? {
        let resp: InstanceInfoResponse = try await client.request(
            "/v1/instances/\(id)", method: .get, as: InstanceInfoResponse.self
        )
        return resp.info
    }

    // MARK: Bot

    static func listBots(instanceId: String) async throws -> [BotListEntry] {
        let resp: BotListResponse = try await client.request(
            "/v1/instances/\(instanceId)/bots", method: .get, as: BotListResponse.self
        )
        return resp.bots
    }

    static func getBotInfo(instanceId: String, botId: String) async throws -> BotInfoResponse {
        try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)", method: .get, as: BotInfoResponse.self
        )
    }

    /// 启动/停止 bot (desired state)
    static func setBotsDesiredState(instanceId: String, botIds: [String], running: Bool) async throws -> [BotStatus] {
        let state = running ? "BOT_DESIRED_STATE_RUNNING" : "BOT_DESIRED_STATE_STOPPED"
        struct Resp: Decodable { let bots: [BotStatus] }
        let resp: Resp = try await client.request(
            "/v1/instances/\(instanceId)/bots:setDesiredState",
            method: .post,
            body: SetBotsDesiredStateRequest(botIds: botIds, desiredState: state),
            as: Resp.self
        )
        return resp.bots
    }

    static func restartBots(instanceId: String, botIds: [String]) async throws {
        struct Resp: Decodable {}
        let _: Resp = try await client.request(
            "/v1/instances/\(instanceId)/bots:restart",
            method: .post,
            body: RestartBotsRequest(botIds: botIds),
            as: Resp.self
        )
    }

    static func sendChat(instanceId: String, botId: String, message: String) async throws {
        let _: SendChatResponse = try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/chat:send",
            method: .post,
            body: SendChatRequest(message: message),
            as: SendChatResponse.self
        )
    }

    static func setRotation(instanceId: String, botId: String, yaw: Double, pitch: Double) async throws {
        let _: EmptyObject = try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/rotation:set",
            method: .post,
            body: SetRotationRequest(yaw: yaw, pitch: pitch),
            as: EmptyObject.self
        )
    }

    static func setMovement(instanceId: String, botId: String, state: MovementState) async throws {
        let _: EmptyObject = try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/movement:set",
            method: .post,
            body: state.toRequest,
            as: EmptyObject.self
        )
    }

    /// 部分更新 (只发送非 nil 字段, 其他保持不变)
    static func setMovement(instanceId: String, botId: String, request: SetMovementStateRequest) async throws {
        let _: EmptyObject = try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/movement:set",
            method: .post,
            body: request,
            as: EmptyObject.self
        )
    }

    static func resetMovement(instanceId: String, botId: String) async throws {
        let _: EmptyObject = try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/movement:reset",
            method: .post, as: EmptyObject.self
        )
    }

    static func setFlying(instanceId: String, botId: String, flying: Bool) async throws {
        let _: EmptyObject = try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId):setFlying",
            method: .post,
            body: SetFlyingRequest(flying: flying),
            as: EmptyObject.self
        )
    }

    static func respawn(instanceId: String, botId: String) async throws {
        let _: EmptyObject = try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/actions:respawn",
            method: .post, as: EmptyObject.self
        )
    }

    static func selectHotbarSlot(instanceId: String, botId: String, slot: Int) async throws {
        let _: EmptyObject = try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/hotbar/\(slot):select",
            method: .post, as: EmptyObject.self
        )
    }

    // MARK: 背包

    static func getInventory(instanceId: String, botId: String) async throws -> BotInventoryStateResponse {
        try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/inventory",
            method: .get, as: BotInventoryStateResponse.self
        )
    }

    static func clickInventorySlot(instanceId: String, botId: String, slot: Int, clickType: String) async throws -> BotInventoryClickResponse {
        struct ClickBody: Encodable { let clickType: String }
        return try await client.request(
            "/v1/instances/\(instanceId)/bots/\(botId)/inventory/slots/\(slot):click",
            method: .post,
            body: ClickBody(clickType: clickType),
            as: BotInventoryClickResponse.self
        )
    }

    // MARK: 账号

    static func addAccount(instanceId: String, account: MinecraftAccount) async throws {
        struct Resp: Decodable {}
        let _: Resp = try await client.request(
            "/v1/instances/\(instanceId)/accounts",
            method: .post,
            body: AddAccountRequest(account: account),
            as: Resp.self
        )
    }

    static func batchAddAccounts(instanceId: String, accounts: [MinecraftAccount]) async throws {
        struct Resp: Decodable {}
        let _: Resp = try await client.request(
            "/v1/instances/\(instanceId)/accounts:batchAdd",
            method: .post,
            body: BatchAddAccountsRequest(accounts: accounts),
            as: Resp.self
        )
    }

    static func removeAccount(instanceId: String, profileId: String) async throws {
        try await client.requestEmpty("/v1/instances/\(instanceId)/accounts/\(profileId)", method: .delete)
    }

    static func batchRemoveAccounts(instanceId: String, profileIds: [String]) async throws {
        struct Resp: Decodable {}
        let _: Resp = try await client.request(
            "/v1/instances/\(instanceId)/accounts:batchRemove",
            method: .post,
            body: BatchRemoveAccountsRequest(profileIds: profileIds),
            as: Resp.self
        )
    }

    // MARK: 代理

    static func addProxy(instanceId: String, proxy: Proxy) async throws {
        struct Resp: Decodable {}
        let _: Resp = try await client.request(
            "/v1/instances/\(instanceId)/proxies",
            method: .post,
            body: AddProxyRequest(proxy: proxy),
            as: Resp.self
        )
    }

    static func batchAddProxies(instanceId: String, proxies: [Proxy]) async throws {
        struct Resp: Decodable {}
        let _: Resp = try await client.request(
            "/v1/instances/\(instanceId)/proxies:batchAdd",
            method: .post,
            body: BatchAddProxiesRequest(proxies: proxies),
            as: Resp.self
        )
    }

    static func removeProxy(instanceId: String, index: Int) async throws {
        try await client.requestEmpty("/v1/instances/\(instanceId)/proxies/\(index)", method: .delete)
    }

    static func updateProxy(instanceId: String, index: Int, proxy: Proxy) async throws {
        struct Resp: Decodable {}
        let _: Resp = try await client.request(
            "/v1/instances/\(instanceId)/proxies/\(index)",
            method: .put,
            body: UpdateProxyRequest(proxy: proxy),
            as: Resp.self
        )
    }

    // MARK: 指令

    static func executeCommand(scope: CommandScope, command: String) async throws -> Int {
        let resp: CommandResponse = try await client.request(
            "/v1/commands:execute",
            method: .post,
            body: ExecuteCommandRequest(scope: scope, command: command),
            as: CommandResponse.self
        )
        return resp.code
    }

    // MARK: 日志

    static func getLogHistory(scope: LogScope, count: Int = 300) async throws -> [LogEntry] {
        let resp: PreviousLogResponse = try await client.request(
            "/v1/logs:history",
            method: .post,
            body: GetPreviousLogsRequest(scope: scope, count: count),
            as: PreviousLogResponse.self
        )
        return resp.messages
    }

    // MARK: 指标

    static func getInstanceMetrics(instanceId: String) async throws -> GetInstanceMetricsResponse {
        try await client.request(
            "/v1/instances/\(instanceId)/metrics",
            method: .get, as: GetInstanceMetricsResponse.self
        )
    }

    static func getServerMetrics() async throws -> [ServerMetricsSnapshot] {
        let resp: GetServerMetricsResponse = try await client.request(
            "/v1/server/metrics", method: .get, as: GetServerMetricsResponse.self
        )
        return resp.snapshots
    }
}
