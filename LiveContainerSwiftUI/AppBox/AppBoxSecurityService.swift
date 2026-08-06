import CryptoKit
import Foundation
import Security

enum AppBoxUnlockResult: Equatable {
    case real
    case decoy
    case failed
}

protocol AppBoxPINProviding {
    var hasPIN: Bool { get }
    var hasDecoyPIN: Bool { get }
    func evaluate(_ pin: String) -> AppBoxUnlockResult
    func verify(_ pin: String) -> Bool
    func verifyDecoy(_ pin: String) -> Bool
    func save(_ pin: String) throws
    func saveDecoy(_ pin: String) throws
    func remove() throws
    func removeDecoy() throws
}

final class AppBoxPINService: AppBoxPINProviding {
    private let service: String
    private let primaryAccount: String
    private let decoyAccount: String
    private let legacyAccount: String

    init(
        service: String = "com.appbox.privacy",
        primaryAccount: String = "pin.primary.sha256",
        decoyAccount: String = "pin.decoy.sha256",
        legacyAccount: String = "pin.sha256"
    ) {
        self.service = service
        self.primaryAccount = primaryAccount
        self.decoyAccount = decoyAccount
        self.legacyAccount = legacyAccount
    }

    var hasPIN: Bool { storedHash(primaryAccount) != nil || storedHash(legacyAccount) != nil }
    var hasDecoyPIN: Bool { storedHash(decoyAccount) != nil }

    func evaluate(_ pin: String) -> AppBoxUnlockResult {
        if verify(pin) { return .real }
        if verifyDecoy(pin) { return .decoy }
        return .failed
    }

    func verify(_ pin: String) -> Bool {
        let pinHash = hash(pin, namespace: primaryAccount)
        if storedHash(primaryAccount) == pinHash { return true }

        let legacyHash = legacyHash(pin)
        return storedHash(legacyAccount) == legacyHash
    }

    func verifyDecoy(_ pin: String) -> Bool {
        storedHash(decoyAccount) == hash(pin, namespace: decoyAccount)
    }

    func save(_ pin: String) throws {
        try saveHash(hash(pin, namespace: primaryAccount), account: primaryAccount)
        try removeAccount(legacyAccount)
    }

    func saveDecoy(_ pin: String) throws {
        try saveHash(hash(pin, namespace: decoyAccount), account: decoyAccount)
    }

    func remove() throws {
        try removeAccount(primaryAccount)
        try removeAccount(legacyAccount)
        try removeAccount(decoyAccount)
    }

    func removeDecoy() throws {
        try removeAccount(decoyAccount)
    }

    private func saveHash(_ pinHash: String, account: String) throws {
        let value = Data(pinHash.utf8)
        let query = baseQuery(account: account)

        if storedHash(account) == pinHash { return }

        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = value
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AppBoxSecurityError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw AppBoxSecurityError.keychain(status)
        }
    }

    private func removeAccount(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppBoxSecurityError.keychain(status)
        }
    }

    private func storedHash(_ account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func hash(_ pin: String, namespace: String) -> String {
        let digest = SHA256.hash(data: Data("AppBox:\(namespace):\(pin)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func legacyHash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data("AppBox:\(pin)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum AppBoxSecurityError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status): return "Keychain error: \(status)"
        }
    }
}
