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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BugReportInsert: Codable {
    let userId: UUID
    let type: String
    let title: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
        case title
        case description
    }
}
