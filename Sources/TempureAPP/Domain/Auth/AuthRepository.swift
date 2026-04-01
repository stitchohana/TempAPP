import Foundation

public protocol AuthRepository: Sendable {
    func sendCode(email: String) async throws
    func verifyCode(email: String, code: String) async throws -> AuthSession
    func refreshToken(refreshToken: String) async throws -> AuthTokens
}
