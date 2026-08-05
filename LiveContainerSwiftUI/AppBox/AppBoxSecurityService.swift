import CryptoKit
import Foundation
import LocalAuthentication
import Security

protocol AppBoxPINProviding {
    var hasPIN: Bool { get }
    func verify(_ pin: String) -> Bool
    func save(_ pin: String) throws
    func remove() throws
}

enum AppBoxBiometryKind: Equatable {
    case faceID
    case touchID
    case opticID
    case unavailable
}

protocol AppBoxBiometricAuthenticating {
    var biometryKind: AppBoxBiometryKind { get }
    func authenticate(reason: String) async throws
}

final class AppBoxBiometricService: AppBoxBiometricAuthenticating {
    var biometryKind: AppBoxBiometryKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? AppBoxSecurityError.biometryUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? AppBoxSecurityError.authenticationFailed)
                }
            }
        }
    }
}

final class AppBoxPINService: AppBoxPINProviding {
    private let service: String
    private let account: String

    init(
        service: String = "com.appbox.privacy",
        account: String = "pin.sha256"
    ) {
        self.service = service
        self.account = account
    }

    var hasPIN: Bool { storedHash() != nil }

    func verify(_ pin: String) -> Bool {
        guard let stored = storedHash() else { return false }
        return stored == hash(pin)
    }

    func save(_ pin: String) throws {
        let pinHash = hash(pin)
        let value = Data(pinHash.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let existing = storedHash(), existing == pinHash { return }
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

    func remove() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppBoxSecurityError.keychain(status)
        }
    }

    private func storedHash() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func hash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data("AppBox:\(pin)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum AppBoxSecurityError: LocalizedError {
    case keychain(OSStatus)
    case biometryUnavailable
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .keychain(let status): return "Keychain error: \(status)"
        case .biometryUnavailable: return "Biometric authentication is unavailable"
        case .authenticationFailed: return "Biometric authentication failed"
        }
    }
}
