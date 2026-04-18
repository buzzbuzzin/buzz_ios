//
//  VerificationGate.swift
//  Buzz
//
//  Created by Xinyu Fang on 4/16/26.
//

import Foundation
import Combine

enum VerificationGateState: Equatable {
    case loading
    case verified
    case unverified
    case networkError
}

@MainActor
protocol IdentityVerificationChecking {
    func checkIdentityVerified(userId: UUID) async throws -> Bool
}

extension IdentityVerificationService: IdentityVerificationChecking {}

@MainActor
protocol DemoModeProviding {
    var isDemoModeEnabled: Bool { get }
}

extension DemoModeManager: DemoModeProviding {}

@MainActor
final class VerificationGate: ObservableObject {
    @Published var state: VerificationGateState = .loading

    private let identityChecker: IdentityVerificationChecking
    private let demoModeProvider: DemoModeProviding
    private let userDefaults: UserDefaults
    private let verifiedCacheKeyPrefix = "verificationGate.verified."
    private var currentUserId: UUID?

    init(userDefaults: UserDefaults = .standard) {
        self.identityChecker = IdentityVerificationService()
        self.demoModeProvider = DemoModeManager.shared
        self.userDefaults = userDefaults
    }

    init(
        identityChecker: IdentityVerificationChecking,
        demoModeProvider: DemoModeProviding,
        userDefaults: UserDefaults = .standard
    ) {
        self.identityChecker = identityChecker
        self.demoModeProvider = demoModeProvider
        self.userDefaults = userDefaults
    }

    func prime(userId: UUID?) {
        guard let userId else {
            currentUserId = nil
            state = .loading
            return
        }

        if currentUserId == userId, state != .loading {
            return
        }

        currentUserId = userId

        if demoModeProvider.isDemoModeEnabled {
            state = .verified
            return
        }

        state = isUserCachedVerified(userId) ? .verified : .loading
    }

    func refresh(userId: UUID?) async {
        guard let userId else {
            currentUserId = nil
            state = .loading
            return
        }

        currentUserId = userId

        if demoModeProvider.isDemoModeEnabled {
            state = .verified
            return
        }

        do {
            let verified = try await identityChecker.checkIdentityVerified(userId: userId)
            if verified {
                cacheVerified(userId)
                state = .verified
            } else {
                clearCachedVerified(userId)
                state = .unverified
            }
        } catch {
            // If we've never successfully resolved verification for this
            // session, surface the error so the user can retry. Otherwise
            // preserve the last-known authoritative state to avoid flashing
            // out of the app on a transient failure.
            if state == .loading {
                state = .networkError
            }
        }
    }

    func retry(userId: UUID?) async {
        state = .loading
        await refresh(userId: userId)
    }

    private func cacheVerified(_ userId: UUID) {
        userDefaults.set(true, forKey: verifiedCacheKey(for: userId))
    }

    private func clearCachedVerified(_ userId: UUID) {
        userDefaults.removeObject(forKey: verifiedCacheKey(for: userId))
    }

    private func isUserCachedVerified(_ userId: UUID) -> Bool {
        userDefaults.bool(forKey: verifiedCacheKey(for: userId))
    }

    private func verifiedCacheKey(for userId: UUID) -> String {
        verifiedCacheKeyPrefix + userId.uuidString.lowercased()
    }
}
