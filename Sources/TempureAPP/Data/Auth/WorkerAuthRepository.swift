import Foundation

public struct WorkerAuthRepository: AuthRepository, Sendable {
    private struct AuthRequest: Encodable {
        let account: String
        let password: String
    }
    private struct RefreshRequest: Encodable { let refreshToken: String }

    private struct AuthResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let user: AuthUser
    }

    private struct RefreshResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
    }

    private let client: CloudflareWorkerClient

    public init(client: CloudflareWorkerClient) {
        self.client = client
    }

    public func register(account: String, password: String) async throws -> AuthSession {
        let response: AuthResponse = try await client.post(
            path: "/auth/register",
            body: AuthRequest(account: account, password: password)
        )
        return AuthSession(
            user: response.user,
            tokens: AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        )
    }

    public func login(account: String, password: String) async throws -> AuthSession {
        let response: AuthResponse = try await client.post(
            path: "/auth/login",
            body: AuthRequest(account: account, password: password)
        )
        return AuthSession(
            user: response.user,
            tokens: AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
        )
    }

    public func refreshToken(refreshToken: String) async throws -> AuthTokens {
        let response: RefreshResponse = try await client.post(path: "/auth/refresh", body: RefreshRequest(refreshToken: refreshToken))
        return AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken ?? refreshToken)
    }
}
