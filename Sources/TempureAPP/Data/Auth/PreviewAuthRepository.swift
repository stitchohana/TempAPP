import Foundation

public struct PreviewAuthRepository: AuthRepository, Sendable {
    public init() {}

    public func sendCode(email: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    public func verifyCode(email: String, code: String) async throws -> AuthSession {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard code == "123456" else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "验证码错误，请输入 123456 体验流程。"])
        }
        return AuthSession(
            user: AuthUser(id: UUID().uuidString, email: email),
            tokens: AuthTokens(accessToken: UUID().uuidString, refreshToken: UUID().uuidString)
        )
    }

    public func refreshToken(refreshToken: String) async throws -> AuthTokens {
        AuthTokens(accessToken: UUID().uuidString, refreshToken: refreshToken)
    }
}
