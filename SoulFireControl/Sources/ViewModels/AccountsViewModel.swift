import SwiftUI
import Observation

// MARK: - 账号管理 VM

@Observable
final class AccountsViewModel {
    let instanceId: String

    var accounts: [MinecraftAccount] = []
    var isLoading = false
    var errorMessage: String?
    var actionMessage: String?

    // 离线账号批量添加
    var offlineUsernames = ""
    var isAdding = false

    init(instanceId: String) {
        self.instanceId = instanceId
    }

    @MainActor
    func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await SoulFireAPI.getInstanceInfo(id: instanceId)
            accounts = info?.config.accounts ?? []
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    /// 解析输入: 每行一个用户名 (支持逗号/空格分隔)
    static func parseUsernames(_ raw: String) -> [String] {
        raw
            .replacingOccurrences(of: ",", with: "\n")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 批量添加离线 (OFFLINE) 账号
    /// profileId 由服务器端从用户名推导, 客户端仅占位空 UUID 结构不合法——
    /// SoulFire 要求 profileId 必填。离线账号的 profileId 为确定性 UUID (基于用户名),
    /// 客户端无法计算, 因此这里发送全零 UUID 占位并说明。
    /// 注: SoulFire 服务端对离线账号实际会重新推导 profileId (见 OfflineJavaData 描述)
    @MainActor
    func addOfflineAccounts() async {
        let usernames = Self.parseUsernames(offlineUsernames)
        guard !usernames.isEmpty else {
            actionMessage = "请输入至少一个用户名"
            return
        }
        isAdding = true
        defer { isAdding = false }

        // 离线账号 UUID (第三版, name 字节 MD5, 详见 OfflinePlayerAuthentication)
        // 客户端直接计算与 Java 版一致的 offline UUID
        let newAccounts: [MinecraftAccount] = usernames.map { name in
            MinecraftAccount(
                type: "OFFLINE",
                profileId: Self.offlineUUID(username: name),
                lastKnownName: name,
                config: nil
            )
        }

        do {
            try await SoulFireAPI.batchAddAccounts(instanceId: instanceId, accounts: newAccounts)
            offlineUsernames = ""
            actionMessage = "已添加 \(newAccounts.count) 个账号"
            await loadAccounts()
        } catch {
            actionMessage = "添加失败：\((error as? APIError)?.localizedDescription ?? error.localizedDescription)"
        }
    }

    /// 计算 Minecraft 离线模式 UUID (与 Java UUID.fromString(OfflinePlayer) 一致)
    /// 算法: md5("OfflinePlayer:" + name) 的第 6/8 字节设置为版本 3 / IETF variant
    static func offlineUUID(username: String) -> String {
        let input = "OfflinePlayer:\(username)"
        let digest = InsecureMD5.hash(input.data(using: .utf8)!)
        var bytes = Array(digest)
        bytes[6] = (bytes[6] & 0x0F) | 0x30 // version 3
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // IETF variant
        // 拼成 8-4-4-4-12 格式 UUID
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let i1 = hex.index(hex.startIndex, offsetBy: 8)
        let i2 = hex.index(hex.startIndex, offsetBy: 12)
        let i3 = hex.index(hex.startIndex, offsetBy: 16)
        let i4 = hex.index(hex.startIndex, offsetBy: 20)
        return "\(hex[..<i1])-\(hex[i1..<i2])-\(hex[i2..<i3])-\(hex[i3..<i4])-\(hex[i4...])"
    }

    @MainActor
    func removeAccount(profileId: String) async {
        do {
            try await SoulFireAPI.removeAccount(instanceId: instanceId, profileId: profileId)
            actionMessage = "已删除账号"
            await loadAccounts()
        } catch {
            actionMessage = "删除失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }

    @MainActor
    func removeSelected(profileIds: [String]) async {
        guard !profileIds.isEmpty else { return }
        do {
            try await SoulFireAPI.batchRemoveAccounts(instanceId: instanceId, profileIds: profileIds)
            actionMessage = "已删除 \(profileIds.count) 个账号"
            await loadAccounts()
        } catch {
            actionMessage = "删除失败：\((error as? APIError)?.localizedDescription ?? "")"
        }
    }
}

// MARK: - 简易 MD5 (离线 UUID 计算)
// CryptoKit 不提供 MD5 (因不再安全), 这里用纯 Swift 实现, 仅用于生成离线账号的确定性 UUID

enum InsecureMD5 {
    static func hash(_ data: Data) -> Data {
        MD5PureSwift.md5(data)
    }
}

enum MD5PureSwift {
    static func md5(_ message: Data) -> Data {
        // 标准 MD5 实现
        let messageBytes = [UInt8](message)
        var messageLength = messageBytes.count * 8

        // padding
        var padded = messageBytes
        padded.append(0x80)
        while padded.count % 64 != 56 {
            padded.append(0)
        }
        // little-endian length
        for shift in stride(from: 0, to: 64, by: 8) {
            padded.append(UInt8((messageLength >> shift) & 0xFF))
        }

        var a0: UInt32 = 0x67452301
        var b0: UInt32 = 0xefcdab89
        var c0: UInt32 = 0x98badcfe
        var d0: UInt32 = 0x10325476

        let s: [UInt32] = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
                           5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
                           4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
                           6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21]
        let K: [UInt32] = (0..<64).map { UInt32(truncatingIfNeeded: Int64(abs(sin(Double($0 + 1)) * pow(2, 32)))) }

        for chunkStart in stride(from: 0, to: padded.count, by: 64) {
            var M = [UInt32](repeating: 0, count: 16)
            for j in 0..<16 {
                let offset = chunkStart + j * 4
                M[j] = UInt32(padded[offset]) | (UInt32(padded[offset + 1]) << 8)
                     | (UInt32(padded[offset + 2]) << 16) | (UInt32(padded[offset + 3]) << 24)
            }
            var A = a0, B = b0, C = c0, D = d0
            for i in 0..<64 {
                var F: UInt32
                var g: Int
                switch i {
                case 0..<16: F = (B & C) | (~B & D); g = i
                case 16..<32: F = (D & B) | (~D & C); g = (5 * i + 1) % 16
                case 32..<48: F = B ^ C ^ D; g = (3 * i + 5) % 16
                default: F = C ^ (B | ~D); g = (7 * i) % 16
                }
                F = F &+ A &+ K[i] &+ M[g]
                A = D
                D = C
                C = B
                B = B &+ ((F << s[i]) | (F >> (32 - s[i])))
            }
            a0 = a0 &+ A
            b0 = b0 &+ B
            c0 = c0 &+ C
            d0 = d0 &+ D
        }

        var out = [UInt8]()
        for v in [a0, b0, c0, d0] {
            out.append(UInt8(v & 0xFF))
            out.append(UInt8((v >> 8) & 0xFF))
            out.append(UInt8((v >> 16) & 0xFF))
            out.append(UInt8((v >> 24) & 0xFF))
        }
        return Data(out)
    }
}
