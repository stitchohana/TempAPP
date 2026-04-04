import Foundation

public protocol AuthRepository: Sendable {
    func register(account: String, password: String) async throws -> AuthSession
    func login(account: String, password: String) async throws -> AuthSession
    func refreshToken(refreshToken: String) async throws -> AuthTokens
}
