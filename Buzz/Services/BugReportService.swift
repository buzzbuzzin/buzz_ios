//
//  BugReportService.swift
//  Buzz
//
//  Created by Claude on 3/7/26.
//

import Foundation
import Supabase
import Combine
import UIKit

@MainActor
class TicketReportService: ObservableObject {
    @Published var reports: [TicketReport] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client

    func fetchMyReports(type: TicketReportType = .bug) async {
        isLoading = true
        errorMessage = nil

        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            reports = []
            isLoading = false
            return
        }

        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                isLoading = false
                errorMessage = "User not authenticated"
                return
            }

            let fetched: [TicketReport] = try await supabase
                .from("ticket_reports")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("type", value: type.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value

            reports = fetched
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func submitReport(title: String, description: String, type: TicketReportType = .bug, images: [UIImage] = []) async throws -> TicketReport {
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            throw NSError(domain: "TicketReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Reports are not available in demo mode"])
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "TicketReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let imageUrls = try await uploadReportImages(userId: userId, images: images)
        let insert = TicketReportInsert(userId: userId, type: type, title: title, description: description, imageUrls: imageUrls)

        let report: TicketReport = try await supabase
            .from("ticket_reports")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        reports.insert(report, at: 0)
        return report
    }

    func submitDispute(bookingId: UUID, reason: DisputeReason, description: String?, images: [UIImage] = []) async throws -> TicketReport {
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            throw NSError(domain: "TicketReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Disputes are not available in demo mode"])
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "TicketReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let imageUrls = try await uploadReportImages(userId: userId, images: images)
        let insert = TicketReportInsert(
            userId: userId,
            type: .dispute,
            title: reason.displayName,
            description: description ?? "",
            imageUrls: imageUrls,
            bookingId: bookingId,
            reason: reason.rawValue
        )

        let report: TicketReport = try await supabase
            .from("ticket_reports")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        reports.insert(report, at: 0)
        return report
    }

    // MARK: - Upload Images

    private func uploadReportImages(userId: UUID, images: [UIImage]) async throws -> [String] {
        if DemoModeManager.shared.isDemoModeEnabled {
            throw NSError(domain: "TicketReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not available in demo mode"])
        }

        var urls: [String] = []

        for image in images.prefix(4) {
            guard let imageData = compressImage(image) else { continue }

            let fileName = "\(userId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

            let _ = try await supabase.storage
                .from("bug-report-images")
                .upload(
                    fileName,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )

            let publicURL = try supabase.storage
                .from("bug-report-images")
                .getPublicURL(path: fileName)

            urls.append(publicURL.absoluteString)
        }

        return urls
    }

    private func compressImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 1200
        let size = image.size

        var newSize: CGSize
        if size.width > maxSize || size.height > maxSize {
            if size.width > size.height {
                newSize = CGSize(width: maxSize, height: (size.height / size.width) * maxSize)
            } else {
                newSize = CGSize(width: (size.width / size.height) * maxSize, height: maxSize)
            }
        } else {
            newSize = size
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.8)
    }
}
