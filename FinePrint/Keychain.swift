// The Gemini key lives in the Keychain, never in UserDefaults or the bundle.
// Saves report their status: an earlier version ignored it, and an unsigned build's
// failed saves went unnoticed.

import Foundation
import Security

enum Keychain {
    private static let service = "com.lekanlawal.fineprint"
    private static let account = "gemini-api-key"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// Returns nil on success, or a readable reason on failure.
    @discardableResult
    static func save(_ value: String) -> String? {
        delete()
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status != errSecSuccess else { return nil }
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
        return "The Keychain refused to save the key (\(message), code \(status))."
    }

    static func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }

    #if DEBUG
    /// Debug-only: save, read back and delete a dummy value under a separate account,
    /// printing the result. Proves Keychain access works without touching a real key.
    static func selfTest() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: "selftest"]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = Data("dummy-value".utf8)
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        var read = q
        read[kSecReturnData as String] = true
        var result: AnyObject?
        let readStatus = SecItemCopyMatching(read as CFDictionary, &result)
        let roundTrip = (result as? Data).flatMap { String(data: $0, encoding: .utf8) } == "dummy-value"
        SecItemDelete(q as CFDictionary)
        print("KEYCHAIN_SELFTEST add=\(addStatus) read=\(readStatus) roundTrip=\(roundTrip)")
    }
    #endif
}
