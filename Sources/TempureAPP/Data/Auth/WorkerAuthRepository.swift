import Foundation

public struct WorkerAuthRepository: AuthRepository, Sendable {
    private struct SendCodeRequest: Encodable { let email: String }
    private struct VerifyCodeRequest: Encodable { let email: String; let code: String }
    private struct RefreshRequest: Encodable { let refreshToken: String }

    private struct VerifyCodeResponse: Decodable {
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

    public func sendCode(email: String) async throws {
        try await client.post(path: "/auth/send-code", body: SendCodeRequest(email: email))
    }

    public func verifyCode(email: String, code: String) async throws -> AuthSession {
        let response: VerifyCodeResponse = try await client.post(path: "/auth/verify-code", body: VerifyCodeRequest(email: email, code: code))
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
