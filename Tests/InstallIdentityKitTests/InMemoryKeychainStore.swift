import Foundation
@testable import InstallIdentityKit

/// In-memory stand-in for the real Keychain so tests are fast, deterministic,
/// and don't depend on a Keychain being available (e.g. Linux CI runners
/// don't have one at all).
final class InMemoryKeychainStore: KeychainStoring {
    private var storage: [String: Data] = [:]

    /// Set to a non-nil status to make the next call fail with that error,
    /// for exercising the library's error paths.
    var forcedError: KeychainError?

    private func key(service: String, account: String) -> String {
        "\(service)|\(account)"
    }

    func read(service: String, account: String) throws -> Data? {
        if let forcedError { throw forcedError }
        return storage[key(service: service, account: account)]
    }

    func write(service: String, account: String, data: Data, accessibility: KeychainAccessibility) throws {
        if let forcedError { throw forcedError }
        storage[key(service: service, account: account)] = data
    }

    func delete(service: String, account: String) throws {
        if let forcedError { throw forcedError }
        storage.removeValue(forKey: key(service: service, account: account))
    }
}
