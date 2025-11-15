//
//  CourseSubscriptionService.swift
//  Buzz
//
//  Created for UAS Pilot Course subscription management
//

import Foundation
import Supabase
import Combine

@MainActor
class CourseSubscriptionService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasActiveSubscription = false
    @Published var subscription: CourseSubscription?
    
    private let supabase = SupabaseClient.shared.client
    
    // UAS Pilot Course UUID (fixed)
    static let uasPilotCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
    
    // MARK: - Check Subscription Status
    
    /// Checks if a pilot has an active subscription for the UAS Pilot Course
    func checkSubscriptionStatus(pilotId: UUID) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [CourseSubscription] = try await supabase
                .from("course_subscriptions")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: Self.uasPilotCourseId.uuidString)
                .eq("status", value: "active")
                .execute()
                .value
            
            hasActiveSubscription = !response.isEmpty
            subscription = response.first
            
            isLoading = false
            return hasActiveSubscription
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            // Return false if no subscription found (not an error)
            hasActiveSubscription = false
            return false
        }
    }
    
    // MARK: - Create Subscription Record
    
    /// Creates a subscription record in the database after successful Stripe payment
    func createSubscriptionRecord(
        pilotId: UUID,
        stripeSubscriptionId: String,
        stripePriceId: String,
        status: String,
        currentPeriodStart: Date,
        currentPeriodEnd: Date
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let subscription: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "course_id": .string(Self.uasPilotCourseId.uuidString),
                "stripe_subscription_id": .string(stripeSubscriptionId),
                "stripe_price_id": .string(stripePriceId),
                "status": .string(status),
                "current_period_start": .string(ISO8601DateFormatter().string(from: currentPeriodStart)),
                "current_period_end": .string(ISO8601DateFormatter().string(from: currentPeriodEnd))
            ]
            
            try await supabase
                .from("course_subscriptions")
                .upsert(subscription, onConflict: "pilot_id,course_id")
                .execute()
            
            hasActiveSubscription = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Update Subscription Status
    
    /// Updates subscription status (e.g., when canceled)
    func updateSubscriptionStatus(
        pilotId: UUID,
        status: String,
        currentPeriodStart: Date? = nil,
        currentPeriodEnd: Date? = nil
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            var updateData: [String: AnyJSON] = [
                "status": .string(status)
            ]
            
            if let start = currentPeriodStart {
                updateData["current_period_start"] = .string(ISO8601DateFormatter().string(from: start))
            }
            
            if let end = currentPeriodEnd {
                updateData["current_period_end"] = .string(ISO8601DateFormatter().string(from: end))
            }
            
            try await supabase
                .from("course_subscriptions")
                .update(updateData)
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("course_id", value: Self.uasPilotCourseId.uuidString)
                .execute()
            
            if status == "active" {
                hasActiveSubscription = true
            } else {
                hasActiveSubscription = false
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Check Unit Access
    
    /// Checks if a pilot has access to a specific unit
    /// Units 1-3 are free, units 4+ require subscription
    func hasAccessToUnit(pilotId: UUID, unitNumber: Int) async throws -> Bool {
        // Units 1-3 are always free
        if unitNumber <= 3 {
            return true
        }
        
        // Units 4+ require active subscription
        return try await checkSubscriptionStatus(pilotId: pilotId)
    }
}

// MARK: - Course Subscription Model

struct CourseSubscription: Codable, Identifiable {
    let id: UUID
    let pilotId: UUID
    let courseId: UUID
    let stripeSubscriptionId: String?
    let stripePriceId: String?
    let status: String
    let currentPeriodStart: Date?
    let currentPeriodEnd: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case courseId = "course_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case stripePriceId = "stripe_price_id"
        case status
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isActive: Bool {
        status == "active" || status == "trialing"
    }
}

