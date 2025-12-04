//
//  ExamAppointment.swift
//  Buzz
//
//  Model for exam appointments in the Test Center
//

import Foundation
import SwiftUI

// MARK: - Exam Type

enum ExamType: String, Codable, CaseIterable, Identifiable {
    case flightReview = "flight_review"
    case rocA = "roc_a"
    
    var id: String { rawValue }
    
    /// Display name - fallback value, prefer config.displayName
    var displayName: String {
        switch self {
        case .flightReview:
            return "Flight Review"
        case .rocA:
            return "ROC-A Exam"
        }
    }
    
    /// Icon name - fallback value, prefer config.icon
    var icon: String {
        switch self {
        case .flightReview:
            return "person.text.rectangle.fill"
        case .rocA:
            return "antenna.radiowaves.left.and.right"
        }
    }
    
    /// Color for this exam type (not configurable from backend)
    var color: Color {
        switch self {
        case .flightReview:
            return .blue
        case .rocA:
            return .blue  // Same blue color as Flight Review for consistency
        }
    }
    
    // MARK: - Config-Based Properties (use ExamService.getConfig() for these)
    // The following properties have been moved to ExamTypeConfig and are fetched from the backend:
    // - shortDescription
    // - fullDescription
    // - durationMinutes
    // - allowsOnline
    // - stripeProductId
    // - prerequisites
    //
    // Use ExamService.shared.getConfig(for: examType) to access these values.
    // Fallback defaults are available in ExamTypeConfig.defaultConfig(for:)
}

// MARK: - Location Type

enum ExamLocationType: String, Codable, CaseIterable, Identifiable {
    case inPerson = "in_person"
    case online = "online"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .inPerson:
            return "In-Person"
        case .online:
            return "Online (Zoom)"
        }
    }
    
    var icon: String {
        switch self {
        case .inPerson:
            return "mappin.and.ellipse"
        case .online:
            return "video.fill"
        }
    }
}

// MARK: - Appointment Status

enum ExamAppointmentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .confirmed:
            return "Confirmed"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .pending:
            return .orange
        case .confirmed:
            return .green
        case .completed:
            return .blue
        case .cancelled:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .pending:
            return "clock"
        case .confirmed:
            return "checkmark.circle"
        case .completed:
            return "checkmark.seal.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }
}

// MARK: - Exam Appointment Model

struct ExamAppointment: Identifiable, Codable {
    let id: UUID
    let pilotId: UUID
    let examType: ExamType
    let scheduledDate: Date
    let durationMinutes: Int
    let locationType: ExamLocationType
    let locationAddress: String?
    let meetingLink: String?
    let zoomMeetingId: String?
    let zoomMeetingPassword: String?
    let status: ExamAppointmentStatus
    let stripePaymentIntentId: String?
    let stripeChargeId: String?
    let paymentAmount: Decimal
    let notes: String?
    let examinerId: UUID?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pilotId = "pilot_id"
        case examType = "exam_type"
        case scheduledDate = "scheduled_date"
        case durationMinutes = "duration_minutes"
        case locationType = "location_type"
        case locationAddress = "location_address"
        case meetingLink = "meeting_link"
        case zoomMeetingId = "zoom_meeting_id"
        case zoomMeetingPassword = "zoom_meeting_password"
        case status
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case stripeChargeId = "stripe_charge_id"
        case paymentAmount = "payment_amount"
        case notes
        case examinerId = "examiner_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom decoder to handle Decimal
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        pilotId = try container.decode(UUID.self, forKey: .pilotId)
        examType = try container.decode(ExamType.self, forKey: .examType)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        locationType = try container.decode(ExamLocationType.self, forKey: .locationType)
        locationAddress = try container.decodeIfPresent(String.self, forKey: .locationAddress)
        meetingLink = try container.decodeIfPresent(String.self, forKey: .meetingLink)
        zoomMeetingId = try container.decodeIfPresent(String.self, forKey: .zoomMeetingId)
        zoomMeetingPassword = try container.decodeIfPresent(String.self, forKey: .zoomMeetingPassword)
        status = try container.decode(ExamAppointmentStatus.self, forKey: .status)
        stripePaymentIntentId = try container.decodeIfPresent(String.self, forKey: .stripePaymentIntentId)
        stripeChargeId = try container.decodeIfPresent(String.self, forKey: .stripeChargeId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        examinerId = try container.decodeIfPresent(UUID.self, forKey: .examinerId)
        
        // Handle date decoding
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let dateString = try? container.decode(String.self, forKey: .scheduledDate),
           let date = dateFormatter.date(from: dateString) {
            scheduledDate = date
        } else {
            scheduledDate = try container.decode(Date.self, forKey: .scheduledDate)
        }
        
        if let createdString = try? container.decode(String.self, forKey: .createdAt),
           let date = dateFormatter.date(from: createdString) {
            createdAt = date
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let updatedString = try? container.decode(String.self, forKey: .updatedAt),
           let date = dateFormatter.date(from: updatedString) {
            updatedAt = date
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
        
        // Handle Decimal from various formats
        if let doubleValue = try? container.decode(Double.self, forKey: .paymentAmount) {
            paymentAmount = Decimal(doubleValue)
        } else if let stringValue = try? container.decode(String.self, forKey: .paymentAmount),
                  let decimalValue = Decimal(string: stringValue) {
            paymentAmount = decimalValue
        } else {
            paymentAmount = 0
        }
    }
    
    // Convenience initializer for creating new appointments
    init(
        id: UUID = UUID(),
        pilotId: UUID,
        examType: ExamType,
        scheduledDate: Date,
        durationMinutes: Int = 30,
        locationType: ExamLocationType,
        locationAddress: String? = nil,
        meetingLink: String? = nil,
        zoomMeetingId: String? = nil,
        zoomMeetingPassword: String? = nil,
        status: ExamAppointmentStatus = .pending,
        stripePaymentIntentId: String? = nil,
        stripeChargeId: String? = nil,
        paymentAmount: Decimal,
        notes: String? = nil,
        examinerId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pilotId = pilotId
        self.examType = examType
        self.scheduledDate = scheduledDate
        self.durationMinutes = durationMinutes
        self.locationType = locationType
        self.locationAddress = locationAddress
        self.meetingLink = meetingLink
        self.zoomMeetingId = zoomMeetingId
        self.zoomMeetingPassword = zoomMeetingPassword
        self.status = status
        self.stripePaymentIntentId = stripePaymentIntentId
        self.stripeChargeId = stripeChargeId
        self.paymentAmount = paymentAmount
        self.notes = notes
        self.examinerId = examinerId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Computed properties
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scheduledDate)
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: paymentAmount as NSDecimalNumber) ?? "$0.00"
    }
    
    var endDate: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: scheduledDate) ?? scheduledDate
    }
    
    /// Returns true if the meeting link is a valid Zoom link (not a placeholder)
    var hasValidZoomLink: Bool {
        guard let link = meetingLink else { return false }
        return link.contains("zoom.us") && !link.contains("placeholder") && !link.contains("pending")
    }
    
    /// Returns the full Zoom meeting info for display
    var zoomMeetingInfo: String? {
        guard let link = meetingLink, hasValidZoomLink else { return nil }
        if let password = zoomMeetingPassword, !password.isEmpty {
            return "\(link)\nPassword: \(password)"
        }
        return link
    }
}

// MARK: - Exam Price Response

struct ExamPriceResponse: Codable {
    let productId: String
    let priceId: String
    let unitAmount: Int // Amount in cents
    let currency: String
    let productName: String
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case priceId = "price_id"
        case unitAmount = "unit_amount"
        case currency
        case productName = "product_name"
    }
    
    var formattedPrice: String {
        let amount = Double(unitAmount) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    var decimalAmount: Decimal {
        Decimal(unitAmount) / 100
    }
}

// MARK: - Prerequisites Status

struct ExamPrerequisitesStatus {
    let passedGroundSchoolTest: Bool
    let completedUnit4: Bool
    
    var isEligible: Bool {
        passedGroundSchoolTest && completedUnit4
    }
    
    var missingPrerequisites: [String] {
        var missing: [String] = []
        if !passedGroundSchoolTest {
            missing.append("Pass Ground School Test")
        }
        if !completedUnit4 {
            missing.append("Complete Unit 4 of UAS Pilot Course")
        }
        return missing
    }
}

