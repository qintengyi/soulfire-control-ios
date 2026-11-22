import Foundation
import Security

// MARK: - Keychain 存取
// Token 存 Keychain（kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly）
// 服务器地址非敏感，存 UserDefaults

enum KeychainStore {
    private static let service = "com.soulfire.control"

    static func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-token",
        ]
        // 先删旧的
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-token",
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - 服务器配置持久化

struct ServerConfig: Codable, Equatable {
    var host: String      // 例如 192.168.1.2 或 sf.example.com
    var port: Int         // 默认 38765
    var useHTTPS: Bool    // SoulFire 自身一般不挂 TLS，走 HTTP；若前面有 Nginx 反代 HTTPS 则开启

    var baseURLString: String {
        let scheme = useHTTPS ? "https" : "http"
        let hasPort = useHTTPS ? (port != 443) : (port != 80)
        if hasPort {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }
}

enum ServerConfigStore {
    private static let key = "server_config"

    static func load() -> ServerConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ServerConfig.self, from: data)
    }

    static func save(_ config: ServerConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static var currentBaseURL: URL? {
        guard let config = load() else { return nil }
        return URL(string: config.baseURLString)
    }
}
