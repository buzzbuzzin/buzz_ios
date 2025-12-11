//
//  ChecklistService.swift
//  Buzz
//
//  Created by GPT on 12/11/25.
//

import Foundation
import Combine
import Auth

@MainActor
class ChecklistService: ObservableObject {
    @Published var hasDroneRegistration: Bool = false
    @Published var hasDronePilotLicense: Bool = false
    @Published var isEmailVerified: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let droneRegistrationService = DroneRegistrationService()
    private let licenseService = LicenseUploadService()
    
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
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
