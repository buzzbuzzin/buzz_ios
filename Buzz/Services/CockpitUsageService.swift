//
//  CockpitUsageService.swift
//  Buzz
//

import Foundation
import Supabase

@MainActor
class CockpitUsageService {
    static let shared = CockpitUsageService()
    private let supabase = SupabaseClient.shared.client

    private init() {}

    func logComponentTap(userId: UUID, component: String, section: String) {
        guard !DemoModeManager.shared.isDemoModeEnabled else { return }

        let insert = CockpitUsageLogInsert(
            userId: userId,
            componentName: component,
            sectionName: section
        )

        Task {
            do {
                try await supabase
                    .from("cockpit_usage_logs")
                    .insert(insert)
                    .execute()
            } catch {
                print("CockpitUsageService: Failed to log tap - \(error.localizedDescription)")
            }
        }
    }
}
