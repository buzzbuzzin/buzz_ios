//
//  CockpitUsageLog.swift
//  Buzz
//
//  Created for cockpit usage analytics logging
//

import Foundation

struct CockpitUsageLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let componentName: String
    let sectionName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case componentName = "component_name"
        case sectionName = "section_name"
        case createdAt = "created_at"
    }
}

struct CockpitUsageLogInsert: Encodable {
    let userId: UUID
    let componentName: String
    let sectionName: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case componentName = "component_name"
        case sectionName = "section_name"
    }
}
