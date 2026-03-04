//
//  IntegrationTestHelpers.swift
//  BuzzTests
//
//  Base class for integration tests that call real Supabase.
//  Signs in a test user in setUp and cleans up test data in tearDown.
//

import XCTest
import Supabase
@testable import Buzz

/// Test user credentials (must exist in Supabase Auth + profiles table).
enum TestUser {
    static let email = "apptest@buzzbuzzin.com"
    static let password = "Apptest123"
    static let id = UUID(uuidString: "175a67c4-29f8-4062-af2f-b1827ac62b41")!
}

/// Base class that handles auth and cleanup for integration tests.
@MainActor
class IntegrationTestCase: XCTestCase {

    /// Shortcut to the shared Supabase client.
    var supabase: Supabase.SupabaseClient {
        SupabaseClient.shared.client
    }

    /// Rows to delete in tearDown. Key = table name, Value = array of row IDs.
    private var cleanupRecords: [(table: String, id: UUID)] = []

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        // Sign in the test user with retry to handle Supabase rate limits
        try await signInWithRetry()
    }

    /// Signs in the test user, retrying with exponential backoff on rate-limit (429) errors.
    private func signInWithRetry(maxAttempts: Int = 4) async throws {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                try await supabase.auth.signIn(email: TestUser.email, password: TestUser.password)
                return
            } catch {
                lastError = error
                let isRateLimit = "\(error)".contains("over_request_rate_limit") || "\(error)".contains("429")
                guard isRateLimit, attempt < maxAttempts - 1 else {
                    if !isRateLimit { throw error }
                    break
                }
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000 // 1s, 2s, 4s
                try await Task.sleep(nanoseconds: delay)
            }
        }
        throw lastError!
    }

    override func tearDown() async throws {
        // Delete any rows we created during the test
        for record in cleanupRecords {
            do {
                try await supabase
                    .from(record.table)
                    .delete()
                    .eq("id", value: record.id.uuidString)
                    .execute()
            } catch {
                // Best-effort cleanup; don't fail test for cleanup issues
                print("⚠️ Cleanup failed for \(record.table)/\(record.id): \(error)")
            }
        }
        cleanupRecords.removeAll()

        // Sign out
        try? await supabase.auth.signOut()
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Register a row to be deleted in tearDown.
    func trackForCleanup(table: String, id: UUID) {
        cleanupRecords.append((table: table, id: id))
    }
}
