#if canImport(SwiftUI)
import SwiftUI

import Foundation

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var code: String = ""
    @Published public var isSendingCode: Bool = false
    @Published public var isLoggingIn: Bool = false
    @Published public var countdown: Int = 0
    @Published public var errorMessage: String?

    private let repository: AuthRepository
    private let sessionStore: AuthSessionStore
    private var countdownTask: Task<Void, Never>?

    public init(repository: AuthRepository, sessionStore: AuthSessionStore) {
        self.repository = repository
        self.sessionStore = sessionStore
    }

    deinit {
        countdownTask?.cancel()
    }

    public func sendCode() async {
        guard validateEmail() else { return }
        isSendingCode = true
        defer { isSendingCode = false }

        do {
            try await repository.sendCode(email: email)
            startCountdown()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func login() async {
        guard validateEmail() else { return }
        guard code.count == 6 else {
            errorMessage = "请输入 6 位验证码。"
            return
        }

        isLoggingIn = true
        defer { isLoggingIn = false }

        do {
            let session = try await repository.verifyCode(email: email, code: code)
            sessionStore.save(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateEmail() -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            errorMessage = "请输入有效邮箱地址。"
            return false
        }
        email = trimmed
        return true
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdown = 60
        countdownTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.countdown -= 1
            }
        }
    }
}

#endif
