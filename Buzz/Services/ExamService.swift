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
    @Published var examConfigs: [ExamType: ExamTypeConfig] = [:]
    @Published var isLoadingConfigs = false
    
    private let supabase = SupabaseClient.shared.client
    
    // Singleton for shared config access
    static let shared = ExamService()
    
    // MARK: - Fetch Exam Configurations
    
    /// Fetches exam type configurations from the backend
    /// Results are cached in examConfigs dictionary
    func fetchExamConfigs() async {
        // Skip if already loading or already have configs
        guard !isLoadingConfigs else { return }
        
        isLoadingConfigs = true
        
        do {
            let response: [ExamTypeConfig] = try await supabase
                .from("exam_type_config")
                .select()
                .execute()
                .value
            
            // Map configs to ExamType
            var configs: [ExamType: ExamTypeConfig] = [:]
            for config in response {
                if let examType = ExamType(rawValue: config.examType) {
                    configs[examType] = config
                }
            }
            
            examConfigs = configs
            isLoadingConfigs = false
            print("✅ [ExamService] Loaded \(configs.count) exam configurations")
        } catch {
            isLoadingConfigs = false
            print("⚠️ [ExamService] Failed to load exam configs: \(error.localizedDescription)")
            // Use default configs as fallback
            examConfigs = [
                .flightReview: ExamTypeConfig.defaultFlightReview,
                .rocA: ExamTypeConfig.defaultRocA
            ]
        }
    }
    
    /// Gets the config for an exam type, using cached value or default
    func getConfig(for examType: ExamType) -> ExamTypeConfig {
        return examConfigs[examType] ?? ExamTypeConfig.defaultConfig(for: examType)
    }
    
    /// Ensures configs are loaded, fetching if needed
    func ensureConfigsLoaded() async {
        if examConfigs.isEmpty && !isLoadingConfigs {
            await fetchExamConfigs()
        }
    }
    
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
        
        // Ensure configs are loaded
        await ensureConfigsLoaded()
        let config = getConfig(for: examType)
        
        do {
            struct PriceRequest: Codable {
                let product_id: String
            }
            
            let request = PriceRequest(product_id: config.stripeProductId)
            
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
        
        // Ensure configs are loaded
        await ensureConfigsLoaded()
        let config = getConfig(for: examType)
        
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
                product_id: config.stripeProductId,
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
    
    // MARK: - Create Zoom Meeting
    
    /// Creates a Zoom meeting for online exams
    private func createZoomMeeting(
        examType: ExamType,
        scheduledDate: Date,
        pilotEmail: String?,
        config: ExamTypeConfig
    ) async throws -> ZoomMeetingResponse {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        struct ZoomRequest: Codable {
            let topic: String
            let scheduled_date: String
            let duration_minutes: Int
            let pilot_email: String?
        }
        
        let request = ZoomRequest(
            topic: "\(config.displayName) Exam",
            scheduled_date: dateFormatter.string(from: scheduledDate),
            duration_minutes: config.durationMinutes,
            pilot_email: pilotEmail
        )
        
        let response: ZoomMeetingResponse = try await supabase.functions
            .invoke("create-zoom-meeting", options: FunctionInvokeOptions(
                body: request
            ))
        
        return response
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
        paymentAmount: Decimal,
        pilotEmail: String? = nil
    ) async throws -> ExamAppointment {
        isLoading = true
        errorMessage = nil
        
        // Ensure configs are loaded
        await ensureConfigsLoaded()
        let config = getConfig(for: examType)
        
        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Create Zoom meeting for online exams
            var meetingLink: String? = nil
            var zoomMeetingId: String? = nil
            var zoomMeetingPassword: String? = nil
            
            if locationType == .online {
                do {
                    let zoomMeeting = try await createZoomMeeting(
                        examType: examType,
                        scheduledDate: scheduledDate,
                        pilotEmail: pilotEmail,
                        config: config
                    )
                    meetingLink = zoomMeeting.joinUrl
                    zoomMeetingId = zoomMeeting.meetingId
                    zoomMeetingPassword = zoomMeeting.password
                    print("✅ [ExamService] Created Zoom meeting: \(zoomMeeting.meetingId)")
                } catch {
                    // Log error but continue with placeholder - meeting can be created manually if needed
                    print("⚠️ [ExamService] Failed to create Zoom meeting: \(error.localizedDescription)")
                    meetingLink = "https://zoom.us/j/pending"
                }
            }
            
            var appointmentData: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "exam_type": .string(examType.rawValue),
                "scheduled_date": .string(dateFormatter.string(from: scheduledDate)),
                "duration_minutes": .integer(config.durationMinutes),
                "location_type": .string(locationType.rawValue),
                "location_address": locationAddress.map { .string($0) } ?? .null,
                "meeting_link": meetingLink.map { .string($0) } ?? .null,
                "status": .string(ExamAppointmentStatus.confirmed.rawValue),
                "stripe_payment_intent_id": .string(paymentIntentId),
                "stripe_charge_id": chargeId.map { .string($0) } ?? .null,
                "payment_amount": .double(NSDecimalNumber(decimal: paymentAmount).doubleValue)
            ]
            
            // Add Zoom-specific fields if available
            if let zoomId = zoomMeetingId {
                appointmentData["zoom_meeting_id"] = .string(zoomId)
            }
            if let zoomPassword = zoomMeetingPassword {
                appointmentData["zoom_meeting_password"] = .string(zoomPassword)
            }
            
            let response: [ExamAppointment] = try await supabase
                .from("exam_appointments")
                .insert(appointmentData)
                .select()
                .execute()
                .value
            
            guard let appointment = response.first else {
                throw ExamServiceError.failedToCreateAppointment
            }
            
            // Send confirmation email (don't block on this)
            if let email = pilotEmail {
                Task {
                    await sendConfirmationEmail(
                        appointment: appointment,
                        pilotEmail: email
                    )
                }
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
    
    // MARK: - Send Confirmation Email
    
    /// Sends a confirmation email for the exam appointment
    private func sendConfirmationEmail(
        appointment: ExamAppointment,
        pilotEmail: String
    ) async {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        struct EmailRequest: Codable {
            let pilot_id: String
            let pilot_email: String
            let exam_type: String
            let exam_type_display: String
            let scheduled_date: String
            let duration_minutes: Int
            let location_type: String
            let location_address: String?
            let meeting_link: String?
            let zoom_meeting_password: String?
            let appointment_id: String
        }
        
        let request = EmailRequest(
            pilot_id: appointment.pilotId.uuidString,
            pilot_email: pilotEmail,
            exam_type: appointment.examType.rawValue,
            exam_type_display: appointment.examType.displayName,
            scheduled_date: dateFormatter.string(from: appointment.scheduledDate),
            duration_minutes: appointment.durationMinutes,
            location_type: appointment.locationType.rawValue,
            location_address: appointment.locationAddress,
            meeting_link: appointment.meetingLink,
            zoom_meeting_password: appointment.zoomMeetingPassword,
            appointment_id: appointment.id.uuidString
        )
        
        do {
            let _: EmptyResponse = try await supabase.functions
                .invoke("send-exam-confirmation", options: FunctionInvokeOptions(
                    body: request
                ))
            print("✅ [ExamService] Confirmation email sent to \(pilotEmail)")
        } catch {
            // Don't throw - email is not critical
            print("⚠️ [ExamService] Failed to send confirmation email: \(error.localizedDescription)")
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
            // Cancel the appointment - allow cancelling both pending and confirmed appointments
            try await supabase
                .from("exam_appointments")
                .update(["status": ExamAppointmentStatus.cancelled.rawValue])
                .eq("id", value: appointmentId.uuidString)
                .eq("pilot_id", value: pilotId.uuidString)
                .in("status", values: [ExamAppointmentStatus.pending.rawValue, ExamAppointmentStatus.confirmed.rawValue])
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
    
    // MARK: - Reschedule Appointment
    
    /// Reschedules an exam appointment to a new date/time
    /// Note: Rescheduling is only allowed more than 24 hours before the scheduled time
    func rescheduleAppointment(
        appointmentId: UUID,
        pilotId: UUID,
        newScheduledDate: Date,
        locationType: ExamLocationType,
        locationAddress: String?,
        examType: ExamType,
        pilotEmail: String? = nil
    ) async throws -> ExamAppointment {
        isLoading = true
        errorMessage = nil
        
        // Ensure configs are loaded
        await ensureConfigsLoaded()
        let config = getConfig(for: examType)
        
        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Create new Zoom meeting for online exams
            var meetingLink: String? = nil
            var zoomMeetingId: String? = nil
            var zoomMeetingPassword: String? = nil
            
            if locationType == .online {
                do {
                    let zoomMeeting = try await createZoomMeeting(
                        examType: examType,
                        scheduledDate: newScheduledDate,
                        pilotEmail: pilotEmail,
                        config: config
                    )
                    meetingLink = zoomMeeting.joinUrl
                    zoomMeetingId = zoomMeeting.meetingId
                    zoomMeetingPassword = zoomMeeting.password
                    print("✅ [ExamService] Created new Zoom meeting for reschedule: \(zoomMeeting.meetingId)")
                } catch {
                    print("⚠️ [ExamService] Failed to create Zoom meeting for reschedule: \(error.localizedDescription)")
                    meetingLink = "https://zoom.us/j/pending"
                }
            }
            
            var updateData: [String: AnyJSON] = [
                "scheduled_date": .string(dateFormatter.string(from: newScheduledDate)),
                "location_type": .string(locationType.rawValue),
                "location_address": locationAddress.map { .string($0) } ?? .null,
                "meeting_link": meetingLink.map { .string($0) } ?? .null,
                "zoom_meeting_id": zoomMeetingId.map { .string($0) } ?? .null,
                "zoom_meeting_password": zoomMeetingPassword.map { .string($0) } ?? .null
            ]
            
            let response: [ExamAppointment] = try await supabase
                .from("exam_appointments")
                .update(updateData)
                .eq("id", value: appointmentId.uuidString)
                .eq("pilot_id", value: pilotId.uuidString)
                .in("status", values: [ExamAppointmentStatus.pending.rawValue, ExamAppointmentStatus.confirmed.rawValue])
                .select()
                .execute()
                .value
            
            guard let appointment = response.first else {
                throw ExamServiceError.failedToRescheduleAppointment
            }
            
            // Send confirmation email for rescheduled appointment
            if let email = pilotEmail {
                Task {
                    await sendConfirmationEmail(
                        appointment: appointment,
                        pilotEmail: email
                    )
                }
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

struct EmptyResponse: Codable {}

struct ZoomMeetingResponse: Codable {
    let joinUrl: String
    let meetingId: String
    let password: String
    let startUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case joinUrl = "join_url"
        case meetingId = "meeting_id"
        case password
        case startUrl = "start_url"
    }
}

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
    case failedToRescheduleAppointment
    case prerequisitesNotMet
    case examAlreadyScheduled
    case invalidExamType
    case cannotRescheduleWithin24Hours
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateAppointment:
            return "Failed to create exam appointment. Please try again."
        case .failedToRescheduleAppointment:
            return "Failed to reschedule exam appointment. Please try again."
        case .prerequisitesNotMet:
            return "You must pass the Ground School Test and complete Unit 4 before scheduling this exam."
        case .examAlreadyScheduled:
            return "You already have a pending or confirmed appointment for this exam."
        case .invalidExamType:
            return "Invalid exam type selected."
        case .cannotRescheduleWithin24Hours:
            return "Rescheduling is not available within 24 hours of your scheduled exam."
        }
    }
}

