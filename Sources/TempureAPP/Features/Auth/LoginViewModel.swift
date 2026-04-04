#if canImport(SwiftUI)
import SwiftUI

import Foundation

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var account: String = ""
    @Published public var password: String = ""
    @Published public var confirmPassword: String = ""
    @Published public var isRegisterMode: Bool = false
    @Published public var isSubmitting: Bool = false
    @Published public var errorMessage: String?

    private let repository: AuthRepository
    private let sessionStore: AuthSessionStore
    private let allowedAccountRegex = "^[A-Za-z0-9._@-]{3,64}$"

    public init(repository: AuthRepository, sessionStore: AuthSessionStore) {
        self.repository = repository
        self.sessionStore = sessionStore
    }

    public func toggleMode() {
        isRegisterMode.toggle()
        errorMessage = nil
    }

    public func submit() async {
        guard validateInput() else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let session: AuthSession
            if isRegisterMode {
                session = try await repository.register(account: account, password: password)
            } else {
                session = try await repository.login(account: account, password: password)
            }
            password = ""
            confirmPassword = ""
            errorMessage = nil
            sessionStore.save(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateInput() -> Bool {
        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAccount.isEmpty == false else {
            errorMessage = "请输入账号。"
            return false
        }
        guard trimmedAccount.range(of: allowedAccountRegex, options: .regularExpression) != nil else {
            errorMessage = "账号格式不正确，请使用 3-64 位字母、数字或 . _ @ -。"
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "密码至少 6 位。"
            return false
        }
        if isRegisterMode, password != confirmPassword {
            errorMessage = "两次输入的密码不一致。"
            return false
        }
        account = trimmedAccount
        return true
    }
}

#endif
