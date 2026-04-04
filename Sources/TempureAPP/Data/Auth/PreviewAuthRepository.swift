import Foundation

public struct PreviewAuthRepository: AuthRepository, Sendable {
    public init() {}

    public func register(account: String, password: String) async throws -> AuthSession {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "请输入账号。"])
        }
        guard password.count >= 6 else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "密码至少 6 位。"])
        }
        return AuthSession(
            user: AuthUser(id: UUID().uuidString, email: account),
            tokens: AuthTokens(accessToken: UUID().uuidString, refreshToken: UUID().uuidString)
        )
    }

    public func login(account: String, password: String) async throws -> AuthSession {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard password == "123456" else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "密码错误。预览模式请输入 123456。"])
        }
        return AuthSession(
            user: AuthUser(id: UUID().uuidString, email: account),
            tokens: AuthTokens(accessToken: UUID().uuidString, refreshToken: UUID().uuidString)
        )
    }

    public func refreshToken(refreshToken: String) async throws -> AuthTokens {
        AuthTokens(accessToken: UUID().uuidString, refreshToken: refreshToken)
    }
}
