//
//  VerificationGateTests.swift
//  BuzzTests
//

import XCTest
@testable import Buzz

@MainActor
final class VerificationGateTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "VerificationGateTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPrimeBootstrapsPreviouslyVerifiedUserFromCache() async {
        let userId = UUID()
        let gate = VerificationGate(
            identityChecker: StubIdentityChecker(responses: [.success(true)]),
            demoModeProvider: StubDemoModeProvider(isDemoModeEnabled: false),
            userDefaults: userDefaults
        )

        gate.prime(userId: userId)
        XCTAssertEqual(gate.state, .loading)

        await gate.refresh(userId: userId)
        XCTAssertEqual(gate.state, .verified)

        let offlineGate = VerificationGate(
            identityChecker: StubIdentityChecker(responses: [.failure(StubError.offline)]),
            demoModeProvider: StubDemoModeProvider(isDemoModeEnabled: false),
            userDefaults: userDefaults
        )

        offlineGate.prime(userId: userId)

        XCTAssertEqual(offlineGate.state, .verified)
    }

    func testRefreshErrorPreservesVerifiedState() async {
        let userId = UUID()
        let gate = VerificationGate(
            identityChecker: StubIdentityChecker(responses: [.success(true), .failure(StubError.offline)]),
            demoModeProvider: StubDemoModeProvider(isDemoModeEnabled: false),
            userDefaults: userDefaults
        )

        gate.prime(userId: userId)
        await gate.refresh(userId: userId)
        XCTAssertEqual(gate.state, .verified)

        await gate.refresh(userId: userId)

        XCTAssertEqual(gate.state, .verified)
    }

    func testRefreshErrorDoesNotConvertLoadingIntoUnverified() async {
        let userId = UUID()
        let gate = VerificationGate(
            identityChecker: StubIdentityChecker(responses: [.failure(StubError.offline)]),
            demoModeProvider: StubDemoModeProvider(isDemoModeEnabled: false),
            userDefaults: userDefaults
        )

        gate.prime(userId: userId)
        XCTAssertEqual(gate.state, .loading)

        await gate.refresh(userId: userId)

        XCTAssertEqual(gate.state, .loading)
    }

    func testRefreshFalseMarksUserUnverifiedAndClearsVerifiedCache() async {
        let userId = UUID()
        let gate = VerificationGate(
            identityChecker: StubIdentityChecker(responses: [.success(true), .success(false)]),
            demoModeProvider: StubDemoModeProvider(isDemoModeEnabled: false),
            userDefaults: userDefaults
        )

        gate.prime(userId: userId)
        await gate.refresh(userId: userId)
        XCTAssertEqual(gate.state, .verified)

        await gate.refresh(userId: userId)
        XCTAssertEqual(gate.state, .unverified)

        let reloadedGate = VerificationGate(
            identityChecker: StubIdentityChecker(responses: [.failure(StubError.offline)]),
            demoModeProvider: StubDemoModeProvider(isDemoModeEnabled: false),
            userDefaults: userDefaults
        )

        reloadedGate.prime(userId: userId)

        XCTAssertEqual(reloadedGate.state, .loading)
    }

    func testPrimePreservesResolvedUnverifiedStateForSameUser() async {
        let userId = UUID()
        let gate = VerificationGate(
            identityChecker: StubIdentityChecker(responses: [.success(false)]),
            demoModeProvider: StubDemoModeProvider(isDemoModeEnabled: false),
            userDefaults: userDefaults
        )

        gate.prime(userId: userId)
        await gate.refresh(userId: userId)
        XCTAssertEqual(gate.state, .unverified)

        gate.prime(userId: userId)

        XCTAssertEqual(gate.state, .unverified)
    }
}

final class AppRootDestinationTests: XCTestCase {

    func testUnresolvedSessionRoutesToLaunch() {
        XCTAssertEqual(
            appRootDestination(
                hasResolvedInitialSession: false,
                isAuthenticated: false,
                shouldDelayNavigation: false,
                verificationState: .loading
            ),
            .launch
        )
    }

    func testAuthenticatedLoadingRoutesToVerificationLoading() {
        XCTAssertEqual(
            appRootDestination(
                hasResolvedInitialSession: true,
                isAuthenticated: true,
                shouldDelayNavigation: false,
                verificationState: .loading
            ),
            .verificationLoading
        )
    }

    func testAuthenticatedVerifiedRoutesToMain() {
        XCTAssertEqual(
            appRootDestination(
                hasResolvedInitialSession: true,
                isAuthenticated: true,
                shouldDelayNavigation: false,
                verificationState: .verified
            ),
            .main
        )
    }

    func testAuthenticatedUnverifiedRoutesToOnboarding() {
        XCTAssertEqual(
            appRootDestination(
                hasResolvedInitialSession: true,
                isAuthenticated: true,
                shouldDelayNavigation: false,
                verificationState: .unverified
            ),
            .onboarding
        )
    }

    func testDelayedNavigationRoutesToWelcome() {
        XCTAssertEqual(
            appRootDestination(
                hasResolvedInitialSession: true,
                isAuthenticated: true,
                shouldDelayNavigation: true,
                verificationState: .verified
            ),
            .welcome
        )
    }
}

@MainActor
private final class StubIdentityChecker: IdentityVerificationChecking {
    private var responses: [Result<Bool, Error>]

    init(responses: [Result<Bool, Error>]) {
        self.responses = responses
    }

    func checkIdentityVerified(userId: UUID) async throws -> Bool {
        guard !responses.isEmpty else {
            XCTFail("No stubbed identity-verification response left for \(userId)")
            return false
        }

        let response = responses.removeFirst()
        return try response.get()
    }
}

private struct StubDemoModeProvider: DemoModeProviding {
    let isDemoModeEnabled: Bool
}

private enum StubError: Error {
    case offline
}
