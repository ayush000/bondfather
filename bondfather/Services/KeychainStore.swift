import Foundation
import Security
import os

enum KeychainStore {
    private static let service = "com.bondfather.keychain"

    /// Saves the value as a generic password.
    ///
    /// The item is readable after the first unlock so the background refresh can use it while the
    /// device is locked, and it is never migrated to another device through backups.
    static func setString(_ value: String, forKey key: String) {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(baseQuery(forKey: key) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let addQuery = baseQuery(forKey: key).merging(attributes) { _, new in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        if status != errSecSuccess {
            Logger.keychain.error("Couldn't save keychain item: OSStatus \(status)")
        }
    }

    static func getString(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                Logger.keychain.error("Couldn't read keychain item: OSStatus \(status)")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            Logger.keychain.error("Couldn't delete keychain item: OSStatus \(status)")
        }
    }

    private static func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
