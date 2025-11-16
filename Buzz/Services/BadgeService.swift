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
    @Published var availableBadges: [AvailableBadge] = []
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
                    isRecurrent: false,
                    badgeType: .course
                ),
                Badge(
                    id: UUID(),
                    courseId: UUID(),
                    courseTitle: "Advanced Flight Maneuvers",
                    courseCategory: "Flight Operations",
                    earnedAt: Date().addingTimeInterval(-86400 * 15), // 15 days ago
                    provider: .buzz,
                    expiresAt: nil,
                    isRecurrent: false,
                    badgeType: .course
                ),
                Badge(
                    id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002") ?? UUID(),
                    courseId: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001") ?? UUID(), // Matches demo course
                    courseTitle: "Amazon Prime Air Operations",
                    courseCategory: "Flight Operations",
                    earnedAt: Date().addingTimeInterval(-86400 * 358), // ~1 year ago (358 days)
                    provider: .amazon,
                    expiresAt: Date().addingTimeInterval(86400 * 7), // Expires in 7 days
                    isRecurrent: true,
                    badgeType: .course
                ),
                Badge(
                    id: UUID(),
                    courseId: UUID(),
                    courseTitle: "Amazon Safety & Compliance",
                    courseCategory: "Safety & Regulations",
                    earnedAt: Date().addingTimeInterval(-86400 * 180), // 6 months ago
                    provider: .amazon,
                    expiresAt: Date().addingTimeInterval(86400 * 30), // Expires in 30 days
                    isRecurrent: true,
                    badgeType: .course
                ),
                // Criteria-based badges
                Badge(
                    id: UUID(),
                    courseId: nil,
                    courseTitle: nil,
                    courseCategory: nil,
                    earnedAt: Date().addingTimeInterval(-86400 * 60), // 60 days ago
                    provider: .buzz,
                    expiresAt: nil,
                    isRecurrent: false,
                    badgeType: .exMilitary
                ),
                Badge(
                    id: UUID(),
                    courseId: nil,
                    courseTitle: nil,
                    courseCategory: nil,
                    earnedAt: Date().addingTimeInterval(-86400 * 90), // 90 days ago
                    provider: .buzz,
                    expiresAt: nil,
                    isRecurrent: false,
                    badgeType: .faa
                )
            ]
    }
    
    // MARK: - Fetch Available Badges
    
    func fetchAvailableBadges(pilotId: UUID) async throws {
        do {
            // Check if demo mode is enabled
            if DemoModeManager.shared.isDemoModeEnabled {
                // Demo mode - return sample available badges
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                availableBadges = getDemoAvailableBadges()
                return
            }
            
            // Use the database function to get available badges
            let response = try await supabase
                .rpc("get_available_badges_for_pilot", params: ["pilot_id_param": pilotId.uuidString])
                .execute()
            
            // Parse the response - the RPC returns a table-like structure
            struct BadgeCatalogResponse: Codable {
                let id: UUID
                let badgeType: String
                let title: String
                let category: String?
                let courseId: UUID?
                let iconName: String
                let colorName: String
                let provider: String
                let isRecurrent: Bool
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case badgeType = "badge_type"
                    case title
                    case category
                    case courseId = "course_id"
                    case iconName = "icon_name"
                    case colorName = "color_name"
                    case provider
                    case isRecurrent = "is_recurrent"
                }
            }
            
            let catalogEntries: [BadgeCatalogResponse] = try JSONDecoder().decode([BadgeCatalogResponse].self, from: response.data)
            
            // Convert catalog entries to AvailableBadge
            availableBadges = catalogEntries.map { entry in
                let badgeType = Badge.BadgeType(rawValue: entry.badgeType)
                let provider = Badge.CourseProvider(rawValue: entry.provider) ?? .buzz
                
                return AvailableBadge(
                    id: entry.id,
                    courseId: entry.courseId,
                    courseTitle: entry.title,
                    courseCategory: entry.category ?? "",
                    provider: provider,
                    isRecurrent: entry.isRecurrent,
                    badgeType: badgeType
                )
            }
        } catch {
            print("Error fetching available badges: \(error)")
            // Fallback to old method if function doesn't exist yet
            try await fetchAvailableBadgesFallback(pilotId: pilotId)
        }
    }
    
    // MARK: - Fallback Method (if database function doesn't exist)
    
    private func fetchAvailableBadgesFallback(pilotId: UUID) async throws {
        var allAvailableBadges: [AvailableBadge] = []
        
        // Fetch badges catalog from backend
        let catalogResponse: [BadgeCatalog] = try await supabase
            .from("badges_catalog")
            .select()
            .eq("is_active", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value
        
        // Get earned badges for this pilot
        let earnedBadges: [Badge] = try await supabase
            .from("badges")
            .select()
            .eq("pilot_id", value: pilotId.uuidString)
            .execute()
            .value
        
        let earnedCourseIds = Set(earnedBadges.compactMap { $0.courseId })
        let earnedBadgeTypes = Set(earnedBadges.compactMap { $0.badgeType })
        
        // Process criteria badges from catalog
        for catalogEntry in catalogResponse {
            guard catalogEntry.badgeType != "course" else { continue }
            
            if let badgeType = Badge.BadgeType(rawValue: catalogEntry.badgeType),
               !earnedBadgeTypes.contains(badgeType) {
                let provider = Badge.CourseProvider(rawValue: catalogEntry.provider) ?? .buzz
                
                allAvailableBadges.append(AvailableBadge(
                    id: catalogEntry.id,
                    courseId: catalogEntry.courseId,
                    courseTitle: catalogEntry.title,
                    courseCategory: catalogEntry.category ?? "",
                    provider: provider,
                    isRecurrent: catalogEntry.isRecurrent,
                    badgeType: badgeType
                ))
            }
        }
        
        // Fetch course badges from training_courses
        let coursesResponse: [TrainingCourseResponse] = try await supabase
            .from("training_courses")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        let courseBadges = coursesResponse
            .filter { course in
                !earnedCourseIds.contains(course.id)
            }
            .map { course in
                AvailableBadge(
                    id: course.id,
                    courseId: course.id,
                    courseTitle: course.title,
                    courseCategory: course.category,
                    provider: Badge.CourseProvider(rawValue: course.provider ?? "Buzz") ?? .buzz,
                    isRecurrent: false,
                    badgeType: .course
                )
            }
        
        allAvailableBadges.append(contentsOf: courseBadges)
        availableBadges = allAvailableBadges
    }
    
    // MARK: - Demo Available Badges
    
    private func getDemoAvailableBadges() -> [AvailableBadge] {
        return [
            AvailableBadge(
                id: UUID(),
                courseId: UUID(),
                courseTitle: "Night Operations Certification",
                courseCategory: "Safety & Regulations",
                provider: .buzz,
                isRecurrent: false,
                badgeType: .course
            ),
            AvailableBadge(
                id: UUID(),
                courseId: UUID(),
                courseTitle: "Weather Analysis & Flight Planning",
                courseCategory: "Flight Operations",
                provider: .buzz,
                isRecurrent: false,
                badgeType: .course
            ),
            AvailableBadge(
                id: UUID(),
                courseId: UUID(),
                courseTitle: "T-Mobile Network Operations",
                courseCategory: "Flight Operations",
                provider: .tmobile,
                isRecurrent: false,
                badgeType: .course
            ),
            AvailableBadge(
                id: UUID(),
                courseId: UUID(),
                courseTitle: "Amazon Delivery Operations",
                courseCategory: "Flight Operations",
                provider: .amazon,
                isRecurrent: false,
                badgeType: .course
            ),
            // Criteria-based badges in demo mode
            AvailableBadge(
                id: UUID(),
                courseId: nil,
                courseTitle: "Ex-Military",
                courseCategory: "Service Recognition",
                provider: .buzz,
                isRecurrent: false,
                badgeType: .exMilitary
            ),
            AvailableBadge(
                id: UUID(),
                courseId: nil,
                courseTitle: "Buzz",
                courseCategory: "Partnership",
                provider: .buzz,
                isRecurrent: false,
                badgeType: .buzz
            ),
            AvailableBadge(
                id: UUID(),
                courseId: nil,
                courseTitle: "Government",
                courseCategory: "Service Recognition",
                provider: .buzz,
                isRecurrent: false,
                badgeType: .governmentEmployee
            ),
            AvailableBadge(
                id: UUID(),
                courseId: nil,
                courseTitle: "FAA",
                courseCategory: "Certification",
                provider: .buzz,
                isRecurrent: false,
                badgeType: .faa
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
            // Use the database function to award badge from catalog
            // This ensures badge details come from badges_catalog (single source of truth)
            let response = try await supabase
                .rpc("award_badge_from_catalog", params: [
                    "pilot_id_param": pilotId.uuidString,
                    "course_id_param": courseId.uuidString,
                    "badge_type_param": "course"
                ])
                .execute()
            
            // Refresh badges and available badges
            try await fetchPilotBadges(pilotId: pilotId)
            try await fetchAvailableBadges(pilotId: pilotId)
        } catch {
            print("Error awarding badge via function: \(error)")
            // Fallback to direct insert if function doesn't exist (backward compatibility)
            do {
                let badge: [String: AnyJSON] = [
                    "id": .string(UUID().uuidString),
                    "pilot_id": .string(pilotId.uuidString),
                    "course_id": .string(courseId.uuidString),
                    "course_title": .string(courseTitle),
                    "course_category": .string(courseCategory),
                    "provider": .string(provider.rawValue),
                    "badge_type": .string("course"),
                    "earned_at": .string(ISO8601DateFormatter().string(from: Date())),
                    "expires_at": .null,
                    "is_recurrent": .bool(false)
                ]
                
                try await supabase
                    .from("badges")
                    .insert(badge)
                    .execute()
                
                // Refresh badges and available badges
                try await fetchPilotBadges(pilotId: pilotId)
                try await fetchAvailableBadges(pilotId: pilotId)
            } catch {
                errorMessage = error.localizedDescription
                throw error
            }
        }
    }
}

