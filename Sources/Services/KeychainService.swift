import Foundation
import CryptoKit
import Security

public final class KeychainService: @unchecked Sendable {
    public static let shared = KeychainService()
    private let tokenStorageKey = "gitea_pat_encrypted_token"
    private let deviceKeyStorageKey = "gitea_device_master_key"

    private init() {}

    // MARK: - Server URL
    public func saveServerURL(_ urlString: String) {
        let cleaned = urlString.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        UserDefaults.standard.set(cleaned, forKey: "gitea_server_url")
    }

    public func getServerURL() -> String {
        return UserDefaults.standard.string(forKey: "gitea_server_url") ?? "https://codeberg.org"
    }

    // MARK: - Encryption Key Helper
    private func getOrCreateSymmetricKey() -> SymmetricKey {
        if let existingKeyData = UserDefaults.standard.data(forKey: deviceKeyStorageKey) {
            return SymmetricKey(data: existingKeyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        UserDefaults.standard.set(keyData, forKey: deviceKeyStorageKey)
        return newKey
    }

    // MARK: - Secure Encrypted Token Storage (No macOS Keychain Password Dialogs!)
    public func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        let key = getOrCreateSymmetricKey()

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            if let combined = sealedBox.combined {
                UserDefaults.standard.set(combined, forKey: tokenStorageKey)
                return true
            }
        } catch {
            print("Failed to encrypt token: \(error)")
        }
        return false
    }

    public func getToken() -> String? {
        // First check CryptoKit encrypted storage
        if let combinedData = UserDefaults.standard.data(forKey: tokenStorageKey) {
            let key = getOrCreateSymmetricKey()
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)
                return String(data: decryptedData, encoding: .utf8)
            } catch {
                print("Failed to decrypt token: \(error)")
            }
        }

        // Fallback: check legacy Keychain storage and auto-migrate
        return getLegacyKeychainToken()
    }

    @discardableResult
    public func deleteToken() -> Bool {
        UserDefaults.standard.removeObject(forKey: tokenStorageKey)
        deleteLegacyKeychainToken()
        return true
    }

    // MARK: - Legacy Keychain Fallback & Auto-Migration
    private func getLegacyKeychainToken() -> String? {
        let account = "gitea_pat_token"
        let serviceName = "com.antigravity.gitea-time-tracker"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data, let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Auto-migrate legacy keychain token to encrypted storage
        _ = saveToken(token)
        deleteLegacyKeychainToken()
        return token
    }

    private func deleteLegacyKeychainToken() {
        let account = "gitea_pat_token"
        let serviceName = "com.antigravity.gitea-time-tracker"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
