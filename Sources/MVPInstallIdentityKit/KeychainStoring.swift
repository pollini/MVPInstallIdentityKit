import Foundation

/// Abstraction over a key/value secure store, scoped by `service` + `account`.
///
/// Modeled after the iOS/macOS Keychain, but kept as a protocol so the rest of
/// the library never talks to `Security.framework` directly. This is what
/// makes `InstallIdentifier` unit-testable without touching the real Keychain
/// (which is unreliable / unavailable in plain `swift test` / CI environments).
public protocol KeychainStoring {
    /// Reads the raw bytes stored for `service` + `account`, or `nil` if nothing is stored.
    func read(service: String, account: String) throws -> Data?

    /// Writes `data` for `service` + `account`, overwriting any previous value.
    func write(service: String, account: String, data: Data, accessibility: KeychainAccessibility) throws

    /// Removes any value stored for `service` + `account`. No-op if nothing is stored.
    func delete(service: String, account: String) throws
}

/// Mirrors the subset of `kSecAttrAccessible*` constants relevant to an
/// install identifier, plus whether the item should sync via iCloud
/// Keychain. Kept as our own enum so `KeychainStoring` doesn't leak
/// `Security.framework` types into call sites.
public enum KeychainAccessibility {
    /// Accessible once the device has been unlocked after a reboot, and never
    /// migrates to other devices via iCloud Keychain. This is the right
    /// default for a device-local install identifier.
    case afterFirstUnlockThisDeviceOnly

    /// Accessible whenever the device is unlocked; also device-local only.
    case whenUnlockedThisDeviceOnly

    /// Accessible once the device has been unlocked after a reboot. Unlike
    /// the `ThisDeviceOnly` variants, this item is included when the user
    /// restores an encrypted backup (iCloud or Finder/local) onto a
    /// **replacement** device — e.g. "old iPhone → new iPhone" via Quick
    /// Start / backup restore — so the identity carries over from that one
    /// migration, without opting into ongoing iCloud Keychain sync between
    /// devices used side by side. This is the narrower, more conservative
    /// fallback compared to `afterFirstUnlockSynchronizable`: no dependency
    /// on the iCloud Keychain toggle, no live cross-device merging — just
    /// "survives being restored onto my next device". See the README
    /// section on cross-device identity.
    case afterFirstUnlockMigratable

    /// Accessible once the device has been unlocked after a reboot, and
    /// **synced via iCloud Keychain** to the user's other devices signed
    /// into the same iCloud account (e.g. their next phone after an
    /// upgrade). Opt into this only if you specifically want the identity
    /// to follow the user across their own devices — see the README section
    /// on cross-device identity for the tradeoffs (requires iCloud Keychain
    /// to be enabled; does not apply to devices the item hasn't synced to
    /// yet; no longer purely "one device" scoped).
    case afterFirstUnlockSynchronizable
}

/// Errors surfaced by `KeychainStoring` implementations.
public enum KeychainError: Error, Equatable {
    /// The underlying store rejected the write/read/delete with the given OSStatus.
    case underlying(status: Int32)
    /// The data read back from the store could not be decoded as an `InstallRecord`.
    case corruptedRecord
}
