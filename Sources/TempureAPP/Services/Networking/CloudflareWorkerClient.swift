import Foundation

public struct CloudflareWorkerClient: Sendable {
    public enum ClientError: LocalizedError {
        case invalidURL
        case invalidResponse
        case unauthorized
        case serverError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "服务器地址无效。"
            case .invalidResponse:
                return "服务器响应无效。"
            case .unauthorized:
                return "登录状态已过期，请重新登录。"
            case let .serverError(message):
                return message
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func post<T: Encodable, U: Decodable>(path: String, body: T, bearerToken: String? = nil, decoder: JSONDecoder = JSONDecoder()) async throws -> U {
        let request = try makeRequest(path: path, method: "POST", bearerToken: bearerToken, body: body)
        let (data, response) = try await session.data(for: request)
        return try parseResponse(data: data, response: response, decoder: decoder)
    }

    public func post<T: Encodable>(path: String, body: T, bearerToken: String? = nil) async throws {
        let request = try makeRequest(path: path, method: "POST", bearerToken: bearerToken, body: body)
        let (data, response) = try await session.data(for: request)
        try validateStatus(response: response, data: data)
    }

    public func get<U: Decodable>(path: String, bearerToken: String? = nil, decoder: JSONDecoder = JSONDecoder()) async throws -> U {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        return try parseResponse(data: data, response: response, decoder: decoder)
    }

    private func makeRequest<T: Encodable>(path: String, method: String, bearerToken: String?, body: T) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func parseResponse<U: Decodable>(data: Data, response: URLResponse, decoder: JSONDecoder) throws -> U {
        try validateStatus(response: response, data: data)
        do {
            return try decoder.decode(U.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
    }

    private func validateStatus(response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        let serverMessage = parseServerMessage(data: data)

        switch http.statusCode {
        case 200 ... 299:
            return
        case 401:
            if let message = serverMessage, isTokenAuthError(message) {
                throw ClientError.unauthorized
            }
            if let message = serverMessage {
                throw ClientError.serverError(localizedServerMessage(message))
            }
            throw ClientError.unauthorized
        default:
            if let message = serverMessage {
                throw ClientError.serverError(localizedServerMessage(message))
            }
            throw ClientError.serverError("请求失败（\(http.statusCode)）。")
        }
    }

    private func parseServerMessage(data: Data?) -> String? {
        guard let data else { return nil }
        if let payload = try? JSONDecoder().decode(ErrorPayload.self, from: data),
           payload.error.isEmpty == false
        {
            return payload.error
        }
        if let message = String(data: data, encoding: .utf8), message.isEmpty == false {
            return message
        }
        return nil
    }

    private func isTokenAuthError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("invalid token")
            || normalized.contains("invalid refresh token")
            || normalized == "unauthorized"
    }

    private func localizedServerMessage(_ message: String) -> String {
        switch message {
        case "Account or password incorrect":
            return "账号或密码错误。"
        case "Account already exists":
            return "账号已存在，请直接登录。"
        case "Invalid account":
            return "账号格式不正确。"
        case "Invalid password":
            return "密码格式不正确。"
        case "Account has no password, please register again":
            return "该账号尚未设置密码，请先注册。"
        case "Invalid token", "Invalid refresh token", "Unauthorized":
            return "登录状态已过期，请重新登录。"
        default:
            return message
        }
    }

    private struct ErrorPayload: Decodable {
        let error: String
    }
}
