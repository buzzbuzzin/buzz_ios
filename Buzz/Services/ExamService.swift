//
//  ExamService.swift
//  Buzz
//
//  Service for managing exam appointments in the Test Center
//

import Foundation
import Supabase
import Combine
import StripePaymentSheet

@MainActor
class ExamService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var appointments: [ExamAppointment] = []
    @Published var prerequisitesStatus: ExamPrerequisitesStatus?
    
    private let supabase = SupabaseClient.shared.client
    
    // UAS Pilot Course UUID (fixed) - same as in CourseSubscriptionService
    static let uasPilotCourseId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
    
    // MARK: - Check Prerequisites
    
    /// Checks if a pilot meets the prerequisites for taking exams
    /// Prerequisites: Passed Ground School Test + Completed Unit 4
    func checkPrerequisites(pilotId: UUID) async throws -> ExamPrerequisitesStatus {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check 1: Has passed Ground School Test
            let passedGroundSchoolTest = try await checkGroundSchoolTestPassed(pilotId: pilotId)
            
            // Check 2: Has completed Unit 4
            let completedUnit4 = try await checkUnit4Completed(pilotId: pilotId)
            
            let status = ExamPrerequisitesStatus(
                passedGroundSchoolTest: passedGroundSchoolTest,
                completedUnit4: completedUnit4
            )
            
            prerequisitesStatus = status
            isLoading = false
            return status
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Checks if pilot has passed the Ground School Test
    private func checkGroundSchoolTestPassed(pilotId: UUID) async throws -> Bool {
        let response = try await supabase
            .from("test_results")
            .select("passed")
            .eq("pilot_id", value: pilotId.uuidString)
            .eq("course_id", value: Self.uasPilotCourseId.uuidString)
            .eq("passed", value: true)
            .execute()
        
        let data = response.data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return false
        }
        
        return !jsonArray.isEmpty
    }
    
    /// Checks if pilot has completed Unit 4 of the UAS Pilot Course
    private func checkUnit4Completed(pilotId: UUID) async throws -> Bool {
        // First, get the Unit 4 ID for the UAS Pilot Course
        let unitsResponse = try await supabase
            .from("course_units")
            .select("id")
            .eq("course_id", value: Self.uasPilotCourseId.uuidString)
            .eq("unit_number", value: 4)
            .execute()
        
        let unitsData = unitsResponse.data
        guard let unitsArray = try? JSONSerialization.jsonObject(with: unitsData) as? [[String: Any]],
              let firstUnit = unitsArray.first,
              let unitIdString = firstUnit["id"] as? String else {
            // If Unit 4 doesn't exist, consider this prerequisite as met
            // (shouldn't happen in production)
            print("⚠️ [ExamService] Unit 4 not found for UAS Pilot Course")
            return true
        }
        
        // Check if pilot has completed this unit
        let completionsResponse = try await supabase
            .from("unit_completions")
            .select("id")
            .eq("pilot_id", value: pilotId.uuidString)
            .eq("unit_id", value: unitIdString)
            .execute()
        
        let completionsData = completionsResponse.data
        guard let completionsArray = try? JSONSerialization.jsonObject(with: completionsData) as? [[String: Any]] else {
            return false
        }
        
        return !completionsArray.isEmpty
    }
    
    // MARK: - Fetch Exam Price
    
    /// Fetches the price for an exam from Stripe
    func fetchExamPrice(examType: ExamType) async throws -> ExamPriceResponse {
        isLoading = true
        errorMessage = nil
        
        do {
            struct PriceRequest: Codable {
                let product_id: String
            }
            
            let request = PriceRequest(product_id: examType.stripeProductId)
            
            let response: ExamPriceResponse = try await supabase.functions
                .invoke("get-exam-price", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            return response
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Create Exam Payment Intent
    
    /// Creates a PaymentIntent for an exam booking
    func createExamPaymentIntent(
        examType: ExamType,
        pilotId: UUID,
        scheduledDate: Date,
        locationType: ExamLocationType,
        locationAddress: String?
    ) async throws -> ExamPaymentIntentResponse {
        isLoading = true
        errorMessage = nil
        
        do {
            let dateFormatter = ISO8601DateFormatter()
            
            struct PaymentRequest: Codable {
                let product_id: String
                let pilot_id: String
                let exam_type: String
                let scheduled_date: String
                let location_type: String
                let location_address: String?
            }
            
            let request = PaymentRequest(
                product_id: examType.stripeProductId,
                pilot_id: pilotId.uuidString,
                exam_type: examType.rawValue,
                scheduled_date: dateFormatter.string(from: scheduledDate),
                location_type: locationType.rawValue,
                location_address: locationAddress
            )
            
            let response: ExamPaymentIntentResponse = try await supabase.functions
                .invoke("create-exam-payment", options: FunctionInvokeOptions(
                    body: request
                ))
            
            isLoading = false
            return response
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Create Exam Appointment
    
    /// Creates an exam appointment record in the database after successful payment
    func createExamAppointment(
        pilotId: UUID,
        examType: ExamType,
        scheduledDate: Date,
        locationType: ExamLocationType,
        locationAddress: String?,
        paymentIntentId: String,
        chargeId: String?,
        paymentAmount: Decimal
    ) async throws -> ExamAppointment {
        isLoading = true
        errorMessage = nil
        
        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Generate meeting link placeholder for online exams
            let meetingLink: String? = locationType == .online ? "https://zoom.us/j/placeholder" : nil
            
            let appointmentData: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "exam_type": .string(examType.rawValue),
                "scheduled_date": .string(dateFormatter.string(from: scheduledDate)),
                "duration_minutes": .integer(examType.durationMinutes),
                "location_type": .string(locationType.rawValue),
                "location_address": locationAddress.map { .string($0) } ?? .null,
                "meeting_link": meetingLink.map { .string($0) } ?? .null,
                "status": .string(ExamAppointmentStatus.confirmed.rawValue),
                "stripe_payment_intent_id": .string(paymentIntentId),
                "stripe_charge_id": chargeId.map { .string($0) } ?? .null,
                "payment_amount": .double(NSDecimalNumber(decimal: paymentAmount).doubleValue)
            ]
            
            let response: [ExamAppointment] = try await supabase
                .from("exam_appointments")
                .insert(appointmentData)
                .select()
                .execute()
                .value
            
            guard let appointment = response.first else {
                throw ExamServiceError.failedToCreateAppointment
            }
            
            // Refresh appointments list
            await fetchAppointments(pilotId: pilotId)
            
            isLoading = false
            return appointment
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Fetch Appointments
    
    /// Fetches all exam appointments for a pilot
    func fetchAppointments(pilotId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [ExamAppointment] = try await supabase
                .from("exam_appointments")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("scheduled_date", ascending: false)
                .execute()
                .value
            
            appointments = response
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("Error fetching exam appointments: \(error)")
        }
    }
    
    // MARK: - Cancel Appointment
    
    /// Cancels a pending exam appointment
    func cancelAppointment(appointmentId: UUID, pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase
                .from("exam_appointments")
                .update(["status": ExamAppointmentStatus.cancelled.rawValue])
                .eq("id", value: appointmentId.uuidString)
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("status", value: ExamAppointmentStatus.pending.rawValue)
                .execute()
            
            // Refresh appointments list
            await fetchAppointments(pilotId: pilotId)
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Check if Exam Already Scheduled
    
    /// Checks if a pilot already has a pending/confirmed appointment for this exam type
    func hasExistingAppointment(pilotId: UUID, examType: ExamType) async -> Bool {
        do {
            let response = try await supabase
                .from("exam_appointments")
                .select("id")
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("exam_type", value: examType.rawValue)
                .in("status", values: [ExamAppointmentStatus.pending.rawValue, ExamAppointmentStatus.confirmed.rawValue])
                .execute()
            
            let data = response.data
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return false
            }
            
            return !jsonArray.isEmpty
        } catch {
            print("Error checking existing appointment: \(error)")
            return false
        }
    }
    
    // MARK: - Get Available Time Slots
    
    /// Returns available time slots for a given date
    /// For now, returns standard business hours slots
    func getAvailableTimeSlots(for date: Date) -> [Date] {
        let calendar = Calendar.current
        var slots: [Date] = []
        
        // Generate slots from 9 AM to 5 PM, every 30 minutes
        for hour in 9..<17 {
            for minute in [0, 30] {
                if let slot = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) {
                    slots.append(slot)
                }
            }
        }
        
        return slots
    }
}

// MARK: - Response Models

struct ExamPaymentIntentResponse: Codable {
    let clientSecret: String
    let paymentIntentId: String
    let customerId: String?
    let ephemeralKeySecret: String?
    let amount: Int
    let currency: String
    let productName: String
    
    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case paymentIntentId = "payment_intent_id"
        case customerId = "customer_id"
        case ephemeralKeySecret = "ephemeral_key_secret"
        case amount
        case currency
        case productName = "product_name"
    }
    
    var formattedAmount: String {
        let dollars = Double(amount) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        return formatter.string(from: NSNumber(value: dollars)) ?? "$\(dollars)"
    }
    
    var decimalAmount: Decimal {
        Decimal(amount) / 100
    }
}

// MARK: - Errors

enum ExamServiceError: LocalizedError {
    case failedToCreateAppointment
    case prerequisitesNotMet
    case examAlreadyScheduled
    case invalidExamType
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateAppointment:
            return "Failed to create exam appointment. Please try again."
        case .prerequisitesNotMet:
            return "You must pass the Ground School Test and complete Unit 4 before scheduling this exam."
        case .examAlreadyScheduled:
            return "You already have a pending or confirmed appointment for this exam."
        case .invalidExamType:
            return "Invalid exam type selected."
        }
    }
}

