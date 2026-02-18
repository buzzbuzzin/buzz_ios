//
//  AppVersionTrackingService.swift
//  Buzz
//

import Foundation
import Supabase

@MainActor
class AppVersionTrackingService {
    static let shared = AppVersionTrackingService()
    private let supabase = SupabaseClient.shared.client

    private init() {}

    func trackAppVersion(userId: UUID) {
        guard !DemoModeManager.shared.isDemoModeEnabled else { return }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        let upsert = AppVersionTrackingUpsert(
            userId: userId,
            platform: "ios",
            appVersion: appVersion,
            lastSeenAt: Date()
        )

        Task {
            do {
                try await supabase
                    .from("app_version_tracking")
                    .upsert(upsert, onConflict: "user_id")
                    .execute()
            } catch {
                print("AppVersionTrackingService: Failed to track version - \(error.localizedDescription)")
            }
        }
    }
}
