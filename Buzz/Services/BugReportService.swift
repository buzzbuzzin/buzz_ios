//
//  BugReportService.swift
//  Buzz
//
//  Created by Claude on 3/7/26.
//

import Foundation
import Supabase
import Combine

@MainActor
class BugReportService: ObservableObject {
    @Published var bugReports: [BugReport] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client

    func fetchMyReports() async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            bugReports = []
            isLoading = false
            return
        }

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                isLoading = false
                errorMessage = "User not authenticated"
                return
            }

            let fetched: [BugReport] = try await supabase
                .from("ticket_reports")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            bugReports = fetched
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func submitReport(title: String, description: String, type: String = "bug") async throws -> BugReport {
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            throw NSError(domain: "BugReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bug reports are not available in demo mode"])
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "BugReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let insert = BugReportInsert(userId: userId, type: type, title: title, description: description)

        let report: BugReport = try await supabase
            .from("ticket_reports")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        bugReports.insert(report, at: 0)
        return report
    }
}
