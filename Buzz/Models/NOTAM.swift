//
//  NOTAM.swift
//  Buzz
//
//  Created for NOTAM feature implementation
//

import Foundation
import CoreLocation

/// Represents a NOTAM (Notice to Airmen) from the Notamify API
struct NOTAM: Identifiable, Codable {
    let id: String
    let notamNumber: String
    let icaoCode: String
    let location: String
    let message: String
    let rawText: String
    let startsAt: String  // ISO 8601 date string
    let endsAt: String    // ISO 8601 date string
    let issuedAt: String  // ISO 8601 date string
    let isPermanent: Bool
    let isEstimated: Bool
    let interpretation: NOTAMInterpretation
    
    // MARK: - Date Parsing
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let iso8601FormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private static func parseDate(_ string: String) -> Date {
        // Try with fractional seconds first, then without
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        if let date = iso8601FormatterNoFractional.date(from: string) {
            return date
        }
        return Date() // Fallback to now if parsing fails
    }
    
    /// Parsed start date
    var startDate: Date {
        Self.parseDate(startsAt)
    }
    
    /// Parsed end date
    var endDate: Date {
        Self.parseDate(endsAt)
    }
    
    /// Parsed issued date
    var issuedDate: Date {
        Self.parseDate(issuedAt)
    }
    
    /// Returns the category color for UI display
    var categoryColor: String {
        category.color
    }
    
    /// Convenience accessor for the category
    var category: NOTAMCategory {
        NOTAMCategory(rawValue: interpretation.category) ?? .other
    }
    
    /// Check if the NOTAM is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    /// Check if the NOTAM will be active soon (within 24 hours)
    var isUpcoming: Bool {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        return startDate > now && startDate <= tomorrow
    }
    
    /// Formatted validity period string
    var validityPeriod: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        if isPermanent {
            return "Permanent (from \(formatter.string(from: startDate)))"
        } else {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
    
    /// Short validity description
    var shortValidity: String {
        if isPermanent {
            return "PERM"
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        if endDate < now {
            return "Expired"
        }
        
        let components = calendar.dateComponents([.day, .hour], from: now, to: endDate)
        if let days = components.day, days > 0 {
            return "\(days)d left"
        } else if let hours = components.hour {
            return "\(hours)h left"
        }
        return "Active"
    }
}

/// Interpretation of a NOTAM provided by Notamify's AI
struct NOTAMInterpretation: Codable {
    let category: String
    let subcategory: String?
    let excerpt: String
    let description: String
    let affectedElements: [NOTAMAffectedElement]
    let schedules: [NOTAMSchedule]
    
    enum CodingKeys: String, CodingKey {
        case category
        case subcategory
        case excerpt
        case description
        case affectedElements
        case schedules
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decode(String.self, forKey: .category)
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory)
        excerpt = try container.decode(String.self, forKey: .excerpt)
        description = try container.decode(String.self, forKey: .description)
        affectedElements = try container.decodeIfPresent([NOTAMAffectedElement].self, forKey: .affectedElements) ?? []
        schedules = try container.decodeIfPresent([NOTAMSchedule].self, forKey: .schedules) ?? []
    }
    
    init(category: String, subcategory: String?, excerpt: String, description: String, affectedElements: [NOTAMAffectedElement] = [], schedules: [NOTAMSchedule] = []) {
        self.category = category
        self.subcategory = subcategory
        self.excerpt = excerpt
        self.description = description
        self.affectedElements = affectedElements
        self.schedules = schedules
    }
}

/// Element affected by a NOTAM
struct NOTAMAffectedElement: Codable, Identifiable {
    var id: String { "\(type)-\(identifier)" }
    let type: String
    let identifier: String
    let effect: String
    let details: String
}

/// Schedule information for a NOTAM
struct NOTAMSchedule: Codable, Identifiable {
    var id: String { source }
    let description: String
    let source: String
    let durationHours: Int?
    let isSunriseSunset: Bool
    
    enum CodingKeys: String, CodingKey {
        case description
        case source
        case durationHours
        case isSunriseSunset
    }
}

/// NOTAM categories as classified by Notamify
enum NOTAMCategory: String, CaseIterable {
    case runway = "RUNWAY"
    case taxiway = "TAXIWAY"
    case apron = "APRON"
    case navigation = "NAVIGATION"
    case airspace = "AIRSPACE"
    case obstacle = "OBSTACLE"
    case lighting = "LIGHTING"
    case service = "SERVICE"
    case communication = "COMMUNICATION"
    case procedure = "PROCEDURE"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .runway: return "Runway"
        case .taxiway: return "Taxiway"
        case .apron: return "Apron"
        case .navigation: return "Navigation"
        case .airspace: return "Airspace"
        case .obstacle: return "Obstacle"
        case .lighting: return "Lighting"
        case .service: return "Service"
        case .communication: return "Communication"
        case .procedure: return "Procedure"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .runway: return "road.lanes"
        case .taxiway: return "arrow.triangle.turn.up.right.diamond"
        case .apron: return "airplane.circle"
        case .navigation: return "location.north.fill"
        case .airspace: return "cloud.fill"
        case .obstacle: return "exclamationmark.triangle.fill"
        case .lighting: return "lightbulb.fill"
        case .service: return "wrench.and.screwdriver.fill"
        case .communication: return "antenna.radiowaves.left.and.right"
        case .procedure: return "doc.text.fill"
        case .other: return "info.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .runway: return "red"
        case .taxiway: return "orange"
        case .apron: return "yellow"
        case .navigation: return "blue"
        case .airspace: return "purple"
        case .obstacle: return "red"
        case .lighting: return "yellow"
        case .service: return "gray"
        case .communication: return "green"
        case .procedure: return "indigo"
        case .other: return "gray"
        }
    }
}

// MARK: - API Response Models

/// Response from the get-notams edge function
struct NOTAMResponse: Codable {
    let notams: [NOTAM]
    let airports: [String]
    let totalCount: Int?
    let message: String?
    let error: String?
}
