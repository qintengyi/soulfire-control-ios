import Foundation

// MARK: - API 错误

enum APIError: LocalizedError, Sendable {
    case notConfigured                    // 未配置服务器地址/Token
    case invalidURL
    case unauthorized                      // 401 Token 无效
    case forbidden(String)                 // 403 权限不足
    case serverError(Int, String?)         // 5xx
    case httpError(Int, String?)           // 其他 HTTP 错误
    case decodingFailed(String)
    case networkFailed(Error)              // URLError
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "尚未配置服务器连接，请先在设置中填写地址和 Token"
        case .invalidURL:
            return "服务器地址格式无效"
        case .unauthorized:
            return "认证失败：Token 无效或已过期，请在 SoulFire 服务器终端执行 generate-token api 重新生成"
        case .forbidden(let perm):
            return "权限不足\(perm.isEmpty ? "" : "：\(perm)")"
        case .serverError(let code, let message):
            return "服务器错误 (\(code))\(message.map { "：\($0)" } ?? "")"
        case .httpError(let code, let message):
            return "请求失败 (\(code))\(message.map { "：\($0)" } ?? "")"
        case .decodingFailed(let detail):
            return "响应解析失败：\(detail)"
        case .networkFailed(let error):
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                switch ns.code {
                case NSURLErrorTimedOut: return "连接超时，请检查服务器是否在线"
                case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
                    return "无法连接到服务器，请检查地址、端口和防火墙"
                case NSURLErrorCannotFindHost: return "找不到服务器主机，请检查地址"
                default: break
                }
            }
            return "网络错误：\(error.localizedDescription)"
        case .emptyResponse:
            return "服务器返回了空响应"
        }
    }
}

// MARK: - HTTP 方法

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API 客户端

/// SoulFire HTTP API 客户端
/// Bearer Token 鉴权 + JSON 编解码
final class APIClient: NSObject, @unchecked Sendable {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    // 锁保护的可变配置
    private let lock = NSLock()
    private var _baseURL: URL?
    private var _token: String?

    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        super.init()
    }

    // MARK: 配置

    var isConfigured: Bool {
        lock.lock(); defer { lock.unlock() }
        return _baseURL != nil && _token != nil
    }

    func updateConfig(baseURL: URL?, token: String?) {
        lock.lock(); defer { lock.unlock() }
        _baseURL = baseURL
        _token = token
    }

    private var baseURL: URL? {
        lock.lock(); defer { lock.unlock() }
        return _baseURL
    }

    private var token: String? {
        lock.lock(); defer { lock.unlock() }
        return _token
    }

    // MARK: 请求构造

    /// 无 body 版本
    private func makeRequest(path: String, method: HTTPMethod) throws -> URLRequest {
        guard let baseURL else { throw APIError.notConfigured }
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// 带 body 版本（用 AnyEncodable 擦除类型）
    private func makeRequest(path: String, method: HTTPMethod, body: AnyEncodable?) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method)
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    // MARK: 核心执行

    /// 带 body 请求
    func request<Body: Encodable, Res: Decodable>(
        _ path: String,
        method: HTTPMethod,
        body: Body,
        as type: Res.Type
    ) async throws -> Res {
        let encoderBody = AnyEncodable(body)
        let request = try makeRequest(path: path, method: method, body: encoderBody)
        return try await execute(request, as: Res.self)
    }

    /// 无 body 请求 (GET / 无 body POST)
    func request<Res: Decodable>(
        _ path: String,
        method: HTTPMethod,
        as type: Res.Type
    ) async throws -> Res {
        let request = try makeRequest(path: path, method: method)
        return try await execute(request, as: Res.self)
    }

    /// 执行请求并解码
    private func execute<Res: Decodable>(_ request: URLRequest, as type: Res.Type) async throws -> Res {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.emptyResponse
        }

        switch http.statusCode {
        case 200:
            do {
                return try decoder.decode(Res.self, from: data)
            } catch {
                throw APIError.decodingFailed("\(Res.self): \(error.localizedDescription)")
            }
        case 401: throw APIError.unauthorized
        case 403:
            let msg = (try? decoder.decode(APIErrorBody.self, from: data))?.message
            throw APIError.forbidden(msg ?? "")
        case 500...599:
            let msg = (try? decoder.decode(APIErrorBody.self, from: data))?.message
            throw APIError.serverError(http.statusCode, msg)
        default:
            let msg = (try? decoder.decode(APIErrorBody.self, from: data))?.message
            throw APIError.httpError(http.statusCode, msg)
        }
    }

    /// 不需要解析响应体的操作（返回空对象的接口）
    func requestEmpty(_ path: String, method: HTTPMethod) async throws {
        let _: EmptyObject = try await request(path, method: method, as: EmptyObject.self)
    }

    /// 下载二进制（用于 bot POV 渲染图）
    func requestData(_ path: String) async throws -> Data {
        guard let baseURL else { throw APIError.notConfigured }
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode, nil)
        }
        return data
    }

    /// 连通性测试
    func ping() async throws -> Bool {
        guard isConfigured else { throw APIError.notConfigured }
        // GET /v1/client 只要 Token 有效即返回当前用户信息
        let _: ClientDataResponse = try await request("/v1/client", method: .get, as: ClientDataResponse.self)
        return true
    }
}

// MARK: - 类型擦除 Encodable

struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ wrapped: some Encodable) {
        encodeFunc = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
