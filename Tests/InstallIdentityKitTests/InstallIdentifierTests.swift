import XCTest
@testable import InstallIdentityKit

final class InstallIdentifierTests: XCTestCase {

    private func makeSUT() -> InstallIdentifier {
        InstallIdentifier(
            service: "test.service",
            account: "test.account",
            store: InMemoryKeychainStore()
        )
    }

    func test_resolve_onFirstCall_reportsFirstLaunchEver() throws {
        let sut = makeSUT()

        let info = try sut.resolve()

        XCTAssertTrue(info.isFirstLaunchEver)
    }

    func test_resolve_onSecondCall_reportsNotFirstLaunchEver_andSameIdentity() throws {
        let sut = makeSUT()

        let first = try sut.resolve()
        let second = try sut.resolve()

        XCTAssertFalse(second.isFirstLaunchEver)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.firstSeenDate.timeIntervalSince1970,
                        second.firstSeenDate.timeIntervalSince1970,
                        accuracy: 0.001)
    }

    func test_resolve_persistsAcrossIndependentInstances_sameStore() throws {
        let sharedStore = InMemoryKeychainStore()
        let first = InstallIdentifier(service: "svc", account: "acct", store: sharedStore)
        let second = InstallIdentifier(service: "svc", account: "acct", store: sharedStore)

        let firstInfo = try first.resolve()
        let secondInfo = try second.resolve()

        XCTAssertEqual(firstInfo.id, secondInfo.id)
        XCTAssertTrue(firstInfo.isFirstLaunchEver)
        XCTAssertFalse(secondInfo.isFirstLaunchEver)
    }

    func test_differentServiceOrAccount_areIsolated() throws {
        let sharedStore = InMemoryKeychainStore()
        let a = InstallIdentifier(service: "svc.a", account: "acct", store: sharedStore)
        let b = InstallIdentifier(service: "svc.b", account: "acct", store: sharedStore)

        let infoA = try a.resolve()
        let infoB = try b.resolve()

        XCTAssertNotEqual(infoA.id, infoB.id)
        XCTAssertTrue(infoA.isFirstLaunchEver)
        XCTAssertTrue(infoB.isFirstLaunchEver)
    }

    func test_reset_causesNextResolveToLookLikeFirstLaunchAgain() throws {
        let sut = makeSUT()
        let originalInfo = try sut.resolve()

        try sut.reset()
        let infoAfterReset = try sut.resolve()

        XCTAssertTrue(infoAfterReset.isFirstLaunchEver)
        XCTAssertNotEqual(originalInfo.id, infoAfterReset.id)
    }

    func test_resolve_propagatesUnderlyingKeychainErrors() {
        let store = InMemoryKeychainStore()
        store.forcedError = .underlying(status: -25300) // errSecItemNotFound, arbitrary example
        let sut = InstallIdentifier(service: "svc", account: "acct", store: store)

        XCTAssertThrowsError(try sut.resolve()) { error in
            XCTAssertEqual(error as? KeychainError, .underlying(status: -25300))
        }
    }

    func test_resolve_isThreadSafe_underConcurrentFirstAccess() throws {
        let sharedStore = InMemoryKeychainStore()
        let sut = InstallIdentifier(service: "svc", account: "acct", store: sharedStore)

        var results: [InstallInfo] = []
        let resultsLock = NSLock()
        let group = DispatchGroup()

        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                if let info = try? sut.resolve() {
                    resultsLock.lock()
                    results.append(info)
                    resultsLock.unlock()
                }
                group.leave()
            }
        }
        group.wait()

        XCTAssertEqual(results.count, 20)
        // All concurrent resolutions must agree on a single identity —
        // there must be no race that creates two different UUIDs.
        XCTAssertEqual(Set(results.map(\.id)).count, 1)
    }
}
