import Foundation
import Security

/// `KeychainStoring` implementation backed by the real iOS/macOS Keychain
/// (`kSecClassGenericPassword`).
///
/// Why generic password and not e.g. `kSecClassIdentity`: generic password
/// items are the simplest Keychain class that (a) supports arbitrary opaque
/// `Data` payloads and (b) survives app deletion/reinstall as long as the
/// device itself isn't wiped and the app is reinstalled under the same
/// Team ID. That survival-across-reinstall behavior is the entire point of
/// this library — see the package README for the App Store / privacy caveats
/// that come with relying on it.
public final class SystemKeychainStore: KeychainStoring {

    public init() {}

    public func read(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.underlying(status: status)
        }
    }

    public func write(service: String, account: String, data: Data, accessibility: KeychainAccessibility) throws {
        // Keychain has no "upsert": try add first, fall back to update.
        var addQuery = baseQuery(service: service, account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = accessibility.secAttrValue
        addQuery[kSecAttrSynchronizable as String] = accessibility.isSynchronizable

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }
        guard addStatus == errSecDuplicateItem else {
            throw KeychainError.underlying(status: addStatus)
        }

        let query = baseQuery(service: service, account: account)
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.secAttrValue
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw KeychainError.underlying(status: updateStatus)
        }
    }

    public func delete(service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.underlying(status: status)
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Without this, SecItemCopyMatching/SecItemDelete only match
            // non-synchronizable items, so a record written with
            // `.afterFirstUnlockSynchronizable` (or one synced down from
            // another device) would silently look "not found" on read.
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
    }
}

private extension KeychainAccessibility {
    var secAttrValue: CFString {
        switch self {
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlockSynchronizable:
            // "ThisDeviceOnly" accessibility values are never eligible for
            // iCloud Keychain sync, so the synchronizable case must use the
            // plain (non-"ThisDeviceOnly") accessible-after-first-unlock
            // constant.
            return kSecAttrAccessibleAfterFirstUnlock
        }
    }

    var isSynchronizable: Bool {
        switch self {
        case .afterFirstUnlockThisDeviceOnly, .whenUnlockedThisDeviceOnly:
            return false
        case .afterFirstUnlockSynchronizable:
            return true
        }
    }
}
