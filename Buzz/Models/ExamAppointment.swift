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
    
    var displayName: String {
        switch self {
        case .flightReview:
            return "Flight Review"
        case .rocA:
            return "ROC-A Exam"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .flightReview:
            return "In-person hands-on flight assessment"
        case .rocA:
            return "Radio communication competency exam"
        }
    }
    
    var fullDescription: String {
        switch self {
        case .flightReview:
            return "The Flight Review is an in-person, hands-on assessment that evaluates your ability to plan and execute a drone flight safely. An examiner will observe your pre-flight procedures, flight execution, and post-flight protocols."
        case .rocA:
            return "A Restricted Operator Certificate with Aeronautical Qualification (ROC-A) exam demonstrates your competence in operating aeronautical radio equipment. It ensures you understand and can use proper radiotelephone communication procedures with air traffic control."
        }
    }
    
    var icon: String {
        switch self {
        case .flightReview:
            return "person.text.rectangle.fill"
        case .rocA:
            return "antenna.radiowaves.left.and.right"
        }
    }
    
    var color: Color {
        switch self {
        case .flightReview:
            return .blue
        case .rocA:
            return .blue  // Same blue color as Flight Review for consistency
        }
    }
    
    var stripeProductId: String {
        switch self {
        case .flightReview:
            return "prod_TW3nHwTNX9Xtec"
        case .rocA:
            return "prod_TW3nnJ9zKy3tC3"
        }
    }
    
    var durationMinutes: Int {
        return 15 // Both exams are 15 minutes
    }
    
    var allowsOnline: Bool {
        switch self {
        case .flightReview:
            return false // Flight Review must be in-person
        case .rocA:
            return true // ROC-A can be online or in-person
        }
    }
    
    var prerequisites: [String] {
        return [
            "Passed Ground School Test",
            "Completed Unit 4 of UAS Pilot Course"
        ]
    }
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
        durationMinutes: Int = 15,
        locationType: ExamLocationType,
        locationAddress: String? = nil,
        meetingLink: String? = nil,
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

