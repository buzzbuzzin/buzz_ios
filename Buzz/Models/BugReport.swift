//
//  BugReport.swift
//  Buzz
//
//  Created by Claude on 3/7/26.
//

import Foundation
import SwiftUI

enum BugReportStatus: String, Codable {
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

struct BugReport: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let type: String
    let title: String
    let description: String
    var status: BugReportStatus
    var adminResponse: String?
    let imageUrls: [String]
    let createdAt: Date
    var updatedAt: Date

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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(BugReportStatus.self, forKey: .status)
        adminResponse = try container.decodeIfPresent(String.self, forKey: .adminResponse)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    init(id: UUID, userId: UUID, type: String, title: String, description: String, status: BugReportStatus, adminResponse: String? = nil, imageUrls: [String] = [], createdAt: Date, updatedAt: Date) {
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
    }
}

struct BugReportInsert: Codable {
    let userId: UUID
    let type: String
    let title: String
    let description: String
    let imageUrls: [String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
        case title
        case description
        case imageUrls = "image_urls"
    }
}
