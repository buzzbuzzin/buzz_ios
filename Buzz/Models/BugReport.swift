//
//  BugReport.swift
//  Buzz
//
//  Created by Claude on 3/7/26.
//

import Foundation
import SwiftUI

enum TicketReportType: String, Codable {
    case bug
    case safety
    case dispute

    var listTitle: String {
        switch self {
        case .bug: return "Bug Reports"
        case .safety: return "Safety Reports"
        case .dispute: return "Booking Disputes"
        }
    }

    var createTitle: String {
        switch self {
        case .bug: return "Report a Bug"
        case .safety: return "Report a Safety Issue"
        case .dispute: return "File a Dispute"
        }
    }

    var detailTitle: String {
        switch self {
        case .bug: return "Bug Report Details"
        case .safety: return "Safety Report Details"
        case .dispute: return "Dispute Details"
        }
    }

    var submitButtonTitle: String {
        switch self {
        case .bug: return "Submit Bug Report"
        case .safety: return "Submit Safety Report"
        case .dispute: return "Submit Dispute"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .bug: return "No Bug Reports"
        case .safety: return "No Safety Reports"
        case .dispute: return "No Disputes"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .bug: return "You haven't submitted any bug reports yet"
        case .safety: return "You haven't submitted any safety reports yet"
        case .dispute: return "You haven't filed any disputes"
        }
    }

    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .safety: return "shield.fill"
        case .dispute: return "exclamationmark.bubble.fill"
        }
    }

    var titlePlaceholder: String {
        switch self {
        case .bug: return "Brief description of the bug"
        case .safety: return "Brief description of the safety issue"
        case .dispute: return ""
        }
    }

    var descriptionPlaceholder: String {
        switch self {
        case .bug: return "Please describe the bug in detail, including steps to reproduce..."
        case .safety: return "Please provide as much detail as possible about the safety issue..."
        case .dispute: return "Please describe the issue in detail..."
        }
    }

    var successAlertTitle: String {
        switch self {
        case .bug: return "Bug Report Submitted"
        case .safety: return "Safety Report Submitted"
        case .dispute: return "Dispute Filed"
        }
    }

    var successAlertMessage: String {
        switch self {
        case .bug: return "Thank you for your report. We'll look into it and get back to you."
        case .safety: return "Thank you for reporting this safety issue. We take safety very seriously and will respond promptly."
        case .dispute: return "Your dispute has been submitted and is under review."
        }
    }

    var loadingMessage: String {
        switch self {
        case .bug: return "Loading bug reports..."
        case .safety: return "Loading safety reports..."
        case .dispute: return "Loading disputes..."
        }
    }
}

enum TicketReportStatus: String, Codable {
    case open
    case inProgress = "in_progress"
    case resolved
    case closed

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }

    var color: Color {
        switch self {
        case .open: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        case .closed: return .gray
        }
    }

    var icon: String {
        switch self {
        case .open: return "circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .resolved: return "checkmark.circle.fill"
        case .closed: return "xmark.circle.fill"
        }
    }
}

struct TicketReport: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let type: TicketReportType
    let title: String
    let description: String
    var status: TicketReportStatus
    var adminResponse: String?
    let imageUrls: [String]
    let createdAt: Date
    var updatedAt: Date
    var bookingId: UUID?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case description
        case status
        case adminResponse = "admin_response"
        case imageUrls = "image_urls"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case bookingId = "booking_id"
        case reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        type = try container.decode(TicketReportType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(TicketReportStatus.self, forKey: .status)
        adminResponse = try container.decodeIfPresent(String.self, forKey: .adminResponse)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        bookingId = try container.decodeIfPresent(UUID.self, forKey: .bookingId)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
    }

    init(id: UUID, userId: UUID, type: TicketReportType, title: String, description: String, status: TicketReportStatus, adminResponse: String? = nil, imageUrls: [String] = [], createdAt: Date, updatedAt: Date, bookingId: UUID? = nil, reason: String? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.description = description
        self.status = status
        self.adminResponse = adminResponse
        self.imageUrls = imageUrls
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.bookingId = bookingId
        self.reason = reason
    }
}

struct TicketReportInsert: Codable {
    let userId: UUID
    let type: TicketReportType
    let title: String
    let description: String
    let imageUrls: [String]
    var bookingId: UUID?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
        case title
        case description
        case imageUrls = "image_urls"
        case bookingId = "booking_id"
        case reason
    }
}
