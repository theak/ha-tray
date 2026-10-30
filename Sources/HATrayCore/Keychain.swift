import Foundation
import Security

public struct KeychainError: Error, LocalizedError {
    public let status: OSStatus

    public init(status: OSStatus) { self.status = status }

    public var errorDescription: String? {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
        return "Keychain: \(message) (\(status))"
    }
}

public protocol TokenStore {
    /// `nil` when no token is stored; throws when the keychain can't be read.
    func load() throws -> String?
    func save(_ token: String) throws
    func delete()
}

/// Stores the Home Assistant token as a generic password in the login keychain.
public struct KeychainTokenStore: TokenStore {
    let service: String
    let account: String

    public init(service: String = "io.github.theak.ha-tray", account: String = "ha-token") {
        self.service = service
        self.account = account
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    public func load() throws -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw KeychainError(status: status) }
        return String(data: data, encoding: .utf8)
    }

    public func save(_ token: String) throws {
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query
            q[kSecValueData as String] = data
            let added = SecItemAdd(q as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    public func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
