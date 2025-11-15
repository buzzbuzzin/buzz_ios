//
//  BadgeService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class BadgeService: ObservableObject {
    @Published var badges: [Badge] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch Pilot Badges
    
    func fetchPilotBadges(pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if demo mode is enabled
            if DemoModeManager.shared.isDemoModeEnabled {
                // Demo mode - return sample badges
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
                badges = getDemoBadges()
            } else {
                // Production mode - fetch from database
                let response: [Badge] = try await supabase
                    .from("badges")
                    .select()
                    .eq("pilot_id", value: pilotId.uuidString)
                    .order("earned_at", ascending: false)
                    .execute()
                    .value
                
                badges = response
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("Error fetching badges: \(error)")
            throw error
        }
    }
    
    // MARK: - Demo Data
    
    private func getDemoBadges() -> [Badge] {
        return [
                Badge(
                    id: UUID(),
                    courseId: UUID(),
                    courseTitle: "FAA Part 107 Certification Prep",
                    courseCategory: "Safety & Regulations",
                    earnedAt: Date().addingTimeInterval(-86400 * 30), // 30 days ago
                    provider: .buzz,
                    expiresAt: nil,
                    isRecurrent: false
                ),
                Badge(
                    id: UUID(),
                    courseId: UUID(),
                    courseTitle: "Advanced Flight Maneuvers",
                    courseCategory: "Flight Operations",
                    earnedAt: Date().addingTimeInterval(-86400 * 15), // 15 days ago
                    provider: .buzz,
                    expiresAt: nil,
                    isRecurrent: false
                ),
                Badge(
                    id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002") ?? UUID(),
                    courseId: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001") ?? UUID(), // Matches demo course
                    courseTitle: "Amazon Prime Air Operations",
                    courseCategory: "Flight Operations",
                    earnedAt: Date().addingTimeInterval(-86400 * 358), // ~1 year ago (358 days)
                    provider: .amazon,
                    expiresAt: Date().addingTimeInterval(86400 * 7), // Expires in 7 days
                    isRecurrent: true
                ),
                Badge(
                    id: UUID(),
                    courseId: UUID(),
                    courseTitle: "Amazon Safety & Compliance",
                    courseCategory: "Safety & Regulations",
                    earnedAt: Date().addingTimeInterval(-86400 * 180), // 6 months ago
                    provider: .amazon,
                    expiresAt: Date().addingTimeInterval(86400 * 30), // Expires in 30 days
                    isRecurrent: true
                )
            ]
    }
    
    // MARK: - Award Badge
    
    func awardBadge(pilotId: UUID, courseId: UUID, courseTitle: String, courseCategory: String, provider: Badge.CourseProvider) async throws {
        // In demo mode, just show a success message without actually inserting into database
        if DemoModeManager.shared.isDemoModeEnabled {
            print("Demo Mode: Skipping badge award")
            return
        }
        
        do {
            let badge: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "course_id": .string(courseId.uuidString),
                "course_title": .string(courseTitle),
                "course_category": .string(courseCategory),
                "provider": .string(provider.rawValue),
                "earned_at": .string(ISO8601DateFormatter().string(from: Date())),
                "expires_at": .null,
                "is_recurrent": .bool(false)
            ]
            
            try await supabase
                .from("badges")
                .insert(badge)
                .execute()
            
            // Refresh badges
            try await fetchPilotBadges(pilotId: pilotId)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

