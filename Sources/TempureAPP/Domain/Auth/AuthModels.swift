import Foundation

public struct AuthUser: Codable, Sendable, Equatable {
    public let id: String
    public let email: String

    public init(id: String, email: String) {
        self.id = id
        self.email = email
    }
}

public struct AuthTokens: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String

    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

public struct AuthSession: Codable, Sendable, Equatable {
    public let user: AuthUser
    public let tokens: AuthTokens

    public init(user: AuthUser, tokens: AuthTokens) {
        self.user = user
        self.tokens = tokens
    }
}
