import Foundation

/// Resolves a stable, anonymous per-install identifier that survives app
/// termination and (best-effort, see README) app reinstalls, by persisting
/// it in the Keychain instead of `UserDefaults`.
///
/// Typical use case: telling apart "a user who deleted and reinstalled the
/// app" from "a genuinely new user" when there is no account/login system
/// to key off of — e.g. to avoid re-granting a one-time trial, or to avoid
/// re-showing a first-launch survey.
///
/// This is deliberately *not* a device fingerprinting tool: it identifies
/// "has this app's Keychain entry been created before on this device", and
/// nothing about the device, user, or other apps.
///
/// ```swift
/// let info = InstallIdentifier.shared.resolve()
/// if info.isFirstLaunchEver {
///     // show onboarding, grant first-run trial, etc.
/// }
/// print("anonymous install id:", info.id)
/// print("first seen:", info.firstSeenDate)
/// ```
public final class InstallIdentifier {

    /// Shared instance using the real system Keychain, scoped to the app's
    /// own bundle identifier. Suitable for almost all call sites.
    public static let shared = InstallIdentifier()

    private let service: String
    private let account: String
    private let accessibility: KeychainAccessibility
    private let store: KeychainStoring
    private let lock = NSLock()

    /// - Parameters:
    ///   - service: Keychain `service` attribute. Defaults to the app's bundle
    ///     identifier so the item doesn't collide with other apps' items.
    ///   - account: Keychain `account` attribute — the "key" within `service`.
    ///     Change this only if you need multiple independent identifiers.
    ///   - accessibility: When the item may be read. Defaults to a
    ///     device-local, non-iCloud-synced accessibility level, which is what
    ///     you want for an install identifier.
    ///   - store: Injectable for testing. Defaults to the real Keychain.
    public init(
        service: String = Bundle.main.bundleIdentifier ?? "InstallIdentityKit",
        account: String = "com.installidentitykit.identity",
        accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly,
        store: KeychainStoring = SystemKeychainStore()
    ) {
        self.service = service
        self.account = account
        self.accessibility = accessibility
        self.store = store
    }

    /// Reads the existing install record, or creates and persists a new one
    /// if none exists yet. Safe to call on every app launch — it's cheap and
    /// idempotent after the first call.
    ///
    /// - Throws: `KeychainError` if the Keychain read/write itself fails
    ///   (e.g. device restrictions). Does *not* throw just because no prior
    ///   record exists — that's the normal "first launch" case.
    @discardableResult
    public func resolve() throws -> InstallInfo {
        lock.lock()
        defer { lock.unlock() }

        if let existingData = try store.read(service: service, account: account) {
            guard let record = try? JSONDecoder.installIdentityKit.decode(InstallRecord.self, from: existingData) else {
                throw KeychainError.corruptedRecord
            }
            return InstallInfo(id: record.id, firstSeenDate: record.firstSeenDate, isFirstLaunchEver: false)
        }

        let newRecord = InstallRecord(id: UUID(), firstSeenDate: Date())
        let data = try JSONEncoder.installIdentityKit.encode(newRecord)
        try store.write(service: service, account: account, data: data, accessibility: accessibility)
        return InstallInfo(id: newRecord.id, firstSeenDate: newRecord.firstSeenDate, isFirstLaunchEver: true)
    }

    /// Deletes the persisted record. Intended for debug builds, sign-out
    /// flows that intentionally want a "fresh" identity, or tests — **not**
    /// for production paths that are meant to detect reinstalls, since
    /// calling this defeats the entire purpose of the library.
    public func reset() throws {
        lock.lock()
        defer { lock.unlock() }
        try store.delete(service: service, account: account)
    }
}

private extension JSONEncoder {
    static let installIdentityKit: JSONEncoder = {
        let encoder = JSONEncoder()
        // .secondsSince1970 round-trips the Date exactly; .iso8601 truncates
        // sub-second precision, which made a freshly created record's
        // in-memory firstSeenDate disagree with what a later resolve() reads
        // back from the store.
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()
}

private extension JSONDecoder {
    static let installIdentityKit: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}
