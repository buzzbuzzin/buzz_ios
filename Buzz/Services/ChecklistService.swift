//
//  ChecklistService.swift
//  Buzz
//
//  Created by GPT on 12/11/25.
//

import Foundation
import Combine
import Auth
import Supabase

// MARK: - Supporting Models

struct BookingChecklist: Codable {
    let hasInsurance: Bool?
    let hasFlightPlan: Bool?
    let hasFAAWaiver: Bool?
    
    enum CodingKeys: String, CodingKey {
        case hasInsurance = "has_insurance"
        case hasFlightPlan = "has_flight_plan"
        case hasFAAWaiver = "has_faa_waiver"
    }
}

@MainActor
class ChecklistService: ObservableObject {
    @Published var hasDroneRegistration: Bool = false
    @Published var hasDronePilotLicense: Bool = false
    @Published var isEmailVerified: Bool = false
    @Published var hasInsurance: Bool = false
    @Published var hasFlightPlan: Bool = false
    @Published var hasFAAWaiver: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let droneRegistrationService = DroneRegistrationService()
    private let licenseService = LicenseUploadService()
    private let supabase = SupabaseClient.shared.client
    private let bookingId: UUID?
    
    init(bookingId: UUID? = nil) {
        self.bookingId = bookingId
    }
    
    func loadChecklistStatus(pilotId: UUID, currentUser: User?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await droneRegistrationService.fetchRegistrations(pilotId: pilotId)
            try await licenseService.fetchLicenses(pilotId: pilotId)
            
            let registrationPresent = !droneRegistrationService.registrations.isEmpty
            let dronePilotLicensePresent = licenseService.licenses.contains { license in
                guard let licenseTypeRaw = license.licenseType,
                      let licenseType = LicenseType(rawValue: licenseTypeRaw) else {
                    return false
                }
                return licenseType.category == .dronePilot
            }
            let emailVerified = currentUser?.emailConfirmedAt != nil
            
            hasDroneRegistration = registrationPresent
            hasDronePilotLicense = dronePilotLicensePresent
            isEmailVerified = emailVerified
            
            // Load booking-specific checklist items if bookingId is provided
            if let bookingId = bookingId {
                await loadBookingChecklist(bookingId: bookingId)
            }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Booking-Specific Checklist Management
    
    private func loadBookingChecklist(bookingId: UUID) async {
        let checklist: BookingChecklist? = try? await supabase
            .from("booking_checklists")
            .select()
            .eq("booking_id", value: bookingId.uuidString)
            .single()
            .execute()
            .value
        
        hasInsurance = checklist?.hasInsurance ?? false
        hasFlightPlan = checklist?.hasFlightPlan ?? false
        hasFAAWaiver = checklist?.hasFAAWaiver ?? false
    }
    
    private func saveBookingChecklist() async {
        guard let bookingId = bookingId else { return }
        
        do {
            let checklistData: [String: AnyJSON] = [
                "booking_id": .string(bookingId.uuidString),
                "has_insurance": .bool(hasInsurance),
                "has_flight_plan": .bool(hasFlightPlan),
                "has_faa_waiver": .bool(hasFAAWaiver),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            // Use upsert to insert or update, specifying booking_id as the conflict column
            try await supabase
                .from("booking_checklists")
                .upsert(checklistData, onConflict: "booking_id")
                .execute()
        } catch {
            print("Error saving booking checklist: \(error)")
        }
    }
    
    // MARK: - Toggle Methods
    
    func toggleInsurance() async {
        hasInsurance.toggle()
        await saveBookingChecklist()
    }
    
    func toggleFlightPlan() async {
        hasFlightPlan.toggle()
        await saveBookingChecklist()
    }
    
    func toggleFAAWaiver() async {
        hasFAAWaiver.toggle()
        await saveBookingChecklist()
    }
}
