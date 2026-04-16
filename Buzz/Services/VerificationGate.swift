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
}

@MainActor
final class VerificationGate: ObservableObject {
    @Published var state: VerificationGateState = .loading

    private let identityService = IdentityVerificationService()

    func refresh(userId: UUID?) async {
        guard let userId else {
            state = .unverified
            return
        }

        if DemoModeManager.shared.isDemoModeEnabled {
            state = .verified
            return
        }

        do {
            let verified = try await identityService.checkIdentityVerified(userId: userId)
            state = verified ? .verified : .unverified
        } catch {
            // Preserve the last-known state on transient errors (e.g. offline).
            // Only move to .unverified if we've never successfully resolved.
            if state == .loading {
                state = .unverified
            }
        }
    }
}
