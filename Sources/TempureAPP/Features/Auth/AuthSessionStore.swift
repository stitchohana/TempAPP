#if canImport(SwiftUI)
import SwiftUI

import Foundation

#if canImport(Security)
import Security
#endif

@MainActor
public final class AuthSessionStore: ObservableObject {
    @Published public private(set) var session: AuthSession?

    public var isAuthenticated: Bool { session != nil }

    private let storageKey = "tempure.auth.session"

    public init() {
        session = loadSession()
    }

    public func save(session: AuthSession) {
        self.session = session
        saveData(try? JSONEncoder().encode(session))
    }

    public func update(tokens: AuthTokens) {
        guard let current = session else { return }
        save(session: AuthSession(user: current.user, tokens: tokens))
    }

    public func clear() {
        session = nil
        deleteData()
    }

    private func loadSession() -> AuthSession? {
        guard let data = readData() else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    private func saveData(_ data: Data?) {
        guard let data else { return }
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: storageKey,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
#else
        UserDefaults.standard.set(data, forKey: storageKey)
#endif
    }

    private func readData() -> Data? {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: storageKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
#else
        return UserDefaults.standard.data(forKey: storageKey)
#endif
    }

    private func deleteData() {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: storageKey
        ]
        SecItemDelete(query as CFDictionary)
#else
        UserDefaults.standard.removeObject(forKey: storageKey)
#endif
    }
}

#endif
