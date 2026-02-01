//
//  FlightPlanFormView.swift
//  Buzz
//
//  Created for flight plan and site survey form
//

import SwiftUI
import CoreLocation
import Combine
import Auth
import PDFKit

// MARK: - Design System Colors
private struct FlightPlanColors {
    static let primary = Color(red: 0.02, green: 0.59, blue: 0.92) // sky-500
    static let primaryHover = Color(red: 0.14, green: 0.68, blue: 0.94) // sky-400
    static let textPrimary = Color(red: 0.13, green: 0.16, blue: 0.19) // slate-800
    static let textSecondary = Color(red: 0.58, green: 0.64, blue: 0.69) // slate-400
    static let textMuted = Color(red: 0.71, green: 0.75, blue: 0.79) // slate-300
    static let border = Color(red: 0.89, green: 0.91, blue: 0.93).opacity(0.6) // slate-200/60
    static let borderLight = Color(red: 0.95, green: 0.96, blue: 0.97) // slate-100
    static let background = Color(red: 0.98, green: 0.98, blue: 0.99) // slate-50
    static let cardBackground = Color.white.opacity(0.7)
    static let fieldBackground = Color(red: 0.97, green: 0.98, blue: 0.99).opacity(0.8) // slate-50/80
}

struct FlightPlanFormView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var flightPlanService = FlightPlanService()
    @StateObject private var locationManager = BookingMapLocationManager()
    @Environment(\.dismiss) private var dismiss

    // Booking (required - flight plan is tied to a booking)
    let booking: Booking

    // Flight Plan Section Fields
    @State private var selectedDrone: DroneRegistration?
    @State private var takeoffDate = Date()
    @State private var takeoffTime = Date()
    @State private var location: String = ""
    @State private var locationCoordinates: CLLocationCoordinate2D?

    // Certification Section Fields
    @State private var certificationRegulation: CertificationRegulation? = nil
    @State private var signatureImage: UIImage?
    @State private var signatureDate: Date?
    @State private var showSignaturePad = false

    // Regulatory Section Fields
    @State private var regulatoryAuthority: RegulatoryAuthority = .faa
    @State private var maxAltitude: Int = 400
    @State private var airspaceClass: AirspaceClass = .unknown
    @State private var laancGridCeiling: Int?
    @State private var hasLAANCCoverage: Bool = false  // Indicates if UASFM grid exists at location
    @State private var laancAuthorizationStatus: LAANCAuthorizationStatus = .pending
    @StateObject private var airspaceService = ArcGISAirspaceService()

    // Flight Operations Fields
    @State private var flightOverPeople = false
    @State private var flightOverPeopleExplanation = ""
    @State private var vlosType: VLOSType = .vlos

    // Part 107 Compliance Fields
    @State private var part107Compliant = true
    @State private var part107NonComplianceExplanation = ""

    // Waiver Fields
    @State private var requiresWaiver = false
    @State private var waiverSafetyMitigations = ""
    @State private var waiverOperationalProcedures = ""
    @State private var waiverRiskAnalysis = ""

    // UI State
    @State private var showGenerateConfirmation = false
    @State private var showShareSheet = false
    @State private var showPDFPreview = false
    @State private var generatedPDFData: Data?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isGeocoding = false
    @State private var hasInitializedFromBooking = false
    @State private var showZuluTimeInfo = false
    @State private var showLAANCInfoSheet = false

    // Address autocomplete
    @State private var addressSuggestions: [AddressSuggestion] = []
    @State private var isSearchingAddress = false
    @State private var showAddressSuggestions = false
    @StateObject private var addressSearchDebouncer = AddressSearchDebouncer()

    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Custom Header
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(FlightPlanColors.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.8))
                                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(FlightPlanColors.border, lineWidth: 1)
                                )
                        }
                        
                        Spacer()
                        
                        Text("Flight Plan")
                            .font(.system(size: 18, weight: .semibold))
                            .tracking(0.3)
                            .foregroundColor(FlightPlanColors.textPrimary)
                        
                        Spacer()
                        
                        // Spacer for centering
                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Flight Details Section
                    GlassCard(title: "Flight Details", icon: "airplane") {
                        VStack(spacing: 20) {
                            // Pilot & Callsign Grid
                            HStack(spacing: 16) {
                                GlassReadOnlyField(
                                    label: "Pilot Name",
                                    value: pilotName
                                )
                                
                                GlassReadOnlyField(
                                    label: "Callsign",
                                    value: pilotCallSign,
                                    icon: "antenna.radiowaves.left.and.right"
                                )
                            }

                            // Drone Picker
                            VStack(alignment: .leading, spacing: 8) {
                                GlassLabel(text: "Drone", required: true)

                                if flightPlanService.isLoading {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading drones...")
                                            .font(.subheadline)
                                            .foregroundColor(FlightPlanColors.textSecondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                } else if flightPlanService.registrations.isEmpty {
                                    Text("No drones registered. Please register a drone first.")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                } else {
                                    Menu {
                                        ForEach(flightPlanService.registrations) { drone in
                                            Button {
                                                selectedDrone = drone
                                            } label: {
                                                Text(droneDisplayName(drone))
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            if let drone = selectedDrone {
                                                Text(droneDisplayName(drone))
                                                    .foregroundColor(FlightPlanColors.textPrimary)
                                            } else {
                                                Text("Select a drone")
                                                    .foregroundColor(FlightPlanColors.textMuted)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(FlightPlanColors.textSecondary)
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(FlightPlanColors.border, lineWidth: 1)
                                        )
                                    }

                                    // Display selected drone details
                                    if let drone = selectedDrone {
                                        VStack(alignment: .leading, spacing: 6) {
                                            if let serialNumber = drone.serialNumber {
                                                HStack {
                                                    Text("Serial Number:")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(FlightPlanColors.textSecondary)
                                                    Spacer()
                                                    Text(serialNumber)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(FlightPlanColors.textPrimary)
                                                }
                                            }

                                            if let registrationNumber = drone.registrationNumber {
                                                HStack {
                                                    Text("Registration #:")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(FlightPlanColors.textSecondary)
                                                    Spacer()
                                                    Text(registrationNumber)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(FlightPlanColors.textPrimary)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                    }
                                }
                            }

                            // Date & Time Grid
                            HStack(alignment: .top, spacing: 16) {
                                // Takeoff Date (Read-only from booking)
                                VStack(alignment: .leading, spacing: 8) {
                                    GlassLabel(text: "Takeoff Date", required: false)

                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14))
                                            .foregroundColor(FlightPlanColors.primary)

                                        Text(shortDateString)
                                            .font(.system(size: 15))
                                            .foregroundColor(FlightPlanColors.textPrimary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(FlightPlanColors.fieldBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(FlightPlanColors.border, lineWidth: 1)
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Takeoff Time (Zulu) - Read-only from booking
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 4) {
                                        GlassLabel(text: "Takeoff Time", required: false)
                                        
                                        Button {
                                            showZuluTimeInfo = true
                                        } label: {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(FlightPlanColors.primary)
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        Text("Z")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(FlightPlanColors.primary)

                                        Text(zuluTimeString)
                                            .font(.system(size: 15))
                                            .foregroundColor(FlightPlanColors.textPrimary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(FlightPlanColors.fieldBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(FlightPlanColors.border, lineWidth: 1)
                                    )

                                    // Local time below
                                    Text(localTimeString)
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(0.5)
                                        .foregroundColor(FlightPlanColors.textSecondary)
                                        .padding(.leading, 12)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Location (Read-only from booking)
                            VStack(alignment: .leading, spacing: 8) {
                                GlassLabel(text: "Location", required: false)

                                HStack(spacing: 0) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(FlightPlanColors.textSecondary)
                                        .padding(.leading, 14)

                                    if isGeocoding {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                            Text("Loading address...")
                                                .font(.system(size: 15))
                                                .foregroundColor(FlightPlanColors.textMuted)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 14)
                                    } else {
                                        Text(location.isEmpty ? "Loading..." : location)
                                            .font(.system(size: 15))
                                            .foregroundColor(location.isEmpty ? FlightPlanColors.textMuted : FlightPlanColors.textPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 14)
                                            .lineLimit(2)
                                    }

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(FlightPlanColors.fieldBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FlightPlanColors.border, lineWidth: 1)
                                )

                                if let coords = locationCoordinates {
                                    Text("Coordinates: \(String(format: "%.6f", coords.latitude)), \(String(format: "%.6f", coords.longitude))")
                                        .font(.caption)
                                        .foregroundColor(FlightPlanColors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Regulatory Authority Section
                    GlassCard(title: "Regulatory Authority", icon: "building.columns") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Auto-detected based on flight location")
                                .font(.system(size: 12))
                                .foregroundColor(FlightPlanColors.textSecondary)

                            // Only show the auto-selected regulatory authority
                            if regulatoryAuthority == .faa {
                                CheckboxOption(
                                    title: "FAA",
                                    subtitle: "United States",
                                    isSelected: true,
                                    isDisabled: true
                                )
                            } else {
                                CheckboxOption(
                                    title: "Transport Canada",
                                    subtitle: "Canada",
                                    isSelected: true,
                                    isDisabled: true
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Airspace & Altitude Section
                    GlassCard(title: "Airspace & Altitude", icon: "airplane.circle") {
                        VStack(spacing: 20) {
                            // Max Altitude Input
                            VStack(alignment: .leading, spacing: 8) {
                                GlassLabel(text: "Max Altitude (ft AGL)", required: true)

                                HStack(spacing: 12) {
                                    TextField("400", value: $maxAltitude, format: .number)
                                        .font(.system(size: 16, weight: .medium))
                                        .keyboardType(.numberPad)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .frame(width: 100)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(FlightPlanColors.border, lineWidth: 1)
                                        )

                                    Text("ft AGL")
                                        .font(.system(size: 14))
                                        .foregroundColor(FlightPlanColors.textSecondary)

                                    Spacer()

                                    Button("Reset to 400") {
                                        maxAltitude = 400
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(FlightPlanColors.primary)
                                }

                                if maxAltitude > 400 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        Text("Altitudes above 400 ft AGL require special authorization")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.top, 4)
                                }
                            }

                            // Airspace Class (Auto-populated)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    GlassLabel(text: "Airspace Class", required: false)
                                    if airspaceService.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }
                                }

                                HStack(spacing: 12) {
                                    Image(systemName: "scope")
                                        .font(.system(size: 16))
                                        .foregroundColor(FlightPlanColors.primary)

                                    Text(airspaceClass == .unknown ? "Detecting..." : "Class \(airspaceClass.rawValue)")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(airspaceClass == .unknown ? FlightPlanColors.textMuted : FlightPlanColors.textPrimary)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(FlightPlanColors.fieldBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(FlightPlanColors.border, lineWidth: 1)
                                )
                            }

                            // FAA Authorization Status
                            VStack(alignment: .leading, spacing: 8) {
                                GlassLabel(text: "FAA Authorization Status", required: false)

                                AuthorizationStatusBadge(status: laancAuthorizationStatus)

                                if let ceiling = laancGridCeiling {
                                    Text("FAA Grid Ceiling: \(ceiling) ft")
                                        .font(.system(size: 12))
                                        .foregroundColor(FlightPlanColors.textSecondary)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .onChange(of: maxAltitude) { _ in updateAuthorizationStatus() }
                    .onChange(of: airspaceClass) { _ in updateAuthorizationStatus() }
                    .onChange(of: hasLAANCCoverage) { _ in updateAuthorizationStatus() }

                    // Flight Operations Section
                    GlassCard(title: "Flight Operations", icon: "eye") {
                        VStack(spacing: 20) {
                            // VLOS/BVLOS Selection
                            VStack(alignment: .leading, spacing: 12) {
                                GlassLabel(text: "Visual Line of Sight", required: true)

                                VStack(spacing: 10) {
                                    CheckboxOption(
                                        title: "VLOS",
                                        subtitle: "Visual Line of Sight",
                                        isSelected: vlosType == .vlos,
                                        action: {
                                            vlosType = .vlos
                                            // When switching to VLOS, allow waiver to be toggled off
                                        }
                                    )

                                    CheckboxOption(
                                        title: "BVLOS",
                                        subtitle: "Beyond Visual Line of Sight",
                                        isSelected: vlosType == .bvlos,
                                        action: {
                                            vlosType = .bvlos
                                            // BVLOS requires waiver - auto-enable it
                                            requiresWaiver = true
                                        }
                                    )
                                }

                                if vlosType == .bvlos {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        Text("BVLOS operations require a Civil Regulation waiver")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                    }
                                }
                            }

                            // Flight Over People
                            VStack(alignment: .leading, spacing: 12) {
                                GlassLabel(text: "Flight Over People", required: false)

                                CheckboxOption(
                                    title: "Yes",
                                    subtitle: "This operation involves flying over people",
                                    isSelected: flightOverPeople,
                                    action: { flightOverPeople.toggle() }
                                )

                                if flightOverPeople {
                                    GlassTextEditor(
                                        title: "Explanation",
                                        text: $flightOverPeopleExplanation,
                                        placeholder: "Describe the circumstances and safety measures for flight over people...",
                                        required: true
                                    )
                                    .transition(.opacity)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Civil Regulation Compliance Section
                    GlassCard(title: "Civil Regulation Compliance", icon: "checkmark.shield") {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(spacing: 10) {
                                CheckboxOption(
                                    title: "Compliant",
                                    subtitle: "This flight complies with all applicable civil regulations",
                                    isSelected: part107Compliant,
                                    isDisabled: maxAltitude > 400,
                                    action: { part107Compliant = true }
                                )

                                CheckboxOption(
                                    title: "Non-Compliant",
                                    subtitle: "This flight does not fully comply with applicable civil regulations",
                                    isSelected: !part107Compliant,
                                    isDisabled: maxAltitude > 400,
                                    action: { part107Compliant = false }
                                )
                            }

                            if maxAltitude > 400 {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                    Text("Flights above 400 ft AGL are non-compliant with civil regulations")
                                        .font(.system(size: 12))
                                        .foregroundColor(FlightPlanColors.textSecondary)
                                }
                            }

                            if !part107Compliant {
                                GlassTextEditor(
                                    title: "Non-Compliance Explanation",
                                    text: $part107NonComplianceExplanation,
                                    placeholder: "Explain which civil regulation rules cannot be met and why...",
                                    required: true
                                )
                                .transition(.opacity)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .onChange(of: maxAltitude) { newAltitude in
                        if newAltitude > 400 {
                            part107Compliant = false
                        }
                    }

                    // Waiver Requirement Section
                    GlassCard(title: "Waiver Requirement", icon: "doc.badge.gearshape") {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(spacing: 10) {
                                CheckboxOption(
                                    title: "Requires Waiver",
                                    subtitle: "This operation requires an FAA waiver",
                                    isSelected: requiresWaiver,
                                    isDisabled: vlosType == .bvlos,
                                    action: { requiresWaiver.toggle() }
                                )

                                if vlosType == .bvlos {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(FlightPlanColors.primary)
                                        Text("Waiver is required for BVLOS operations")
                                            .font(.system(size: 12))
                                            .foregroundColor(FlightPlanColors.textSecondary)
                                    }
                                }
                            }

                            if requiresWaiver {
                                VStack(spacing: 16) {
                                    GlassTextEditor(
                                        title: "I. Safety Mitigations",
                                        text: $waiverSafetyMitigations,
                                        placeholder: "Describe safety measures to mitigate risks...",
                                        required: true
                                    )

                                    GlassTextEditor(
                                        title: "II. Operational Procedures",
                                        text: $waiverOperationalProcedures,
                                        placeholder: "Detail the operational procedures for this flight...",
                                        required: true
                                    )

                                    GlassTextEditor(
                                        title: "III. Risk Analysis",
                                        text: $waiverRiskAnalysis,
                                        placeholder: "Provide a risk analysis for this operation...",
                                        required: true
                                    )
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Certification Section
                    GlassCard(title: "Pilot Certification", icon: "signature") {
                        VStack(spacing: 20) {
                            // Certification statement with regulation picker
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 0) {
                                    Text("I certify that this flight will be conducted in accordance with all applicable civil regulations under ")
                                        .font(.system(size: 13))
                                        .foregroundColor(FlightPlanColors.textSecondary)

                                    Spacer()
                                }

                                // Regulation picker - aligned to the right
                                HStack {
                                    Spacer()
                                    Menu {
                                        Section("USA") {
                                            ForEach(CertificationRegulation.usaRegulations, id: \.self) { regulation in
                                                Button {
                                                    certificationRegulation = regulation
                                                } label: {
                                                    HStack {
                                                        Text(regulation.displayName)
                                                        if certificationRegulation == regulation {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Section("Canada") {
                                            ForEach(CertificationRegulation.canadaRegulations, id: \.self) { regulation in
                                                Button {
                                                    certificationRegulation = regulation
                                                } label: {
                                                    HStack {
                                                        Text(regulation.displayName)
                                                        if certificationRegulation == regulation {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            if let regulation = certificationRegulation {
                                                Text(regulation.displayName)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(FlightPlanColors.primary)
                                            } else {
                                                Text("Select Regulation")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(FlightPlanColors.textSecondary)
                                            }

                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(certificationRegulation != nil ? FlightPlanColors.primary : FlightPlanColors.textSecondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(certificationRegulation != nil ? FlightPlanColors.primary.opacity(0.1) : FlightPlanColors.fieldBackground)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(certificationRegulation != nil ? FlightPlanColors.primary.opacity(0.3) : FlightPlanColors.border, lineWidth: 1)
                                        )
                                    }
                                }

                                Text("and that I am the remote pilot in command responsible for this operation.")
                                    .font(.system(size: 13))
                                    .foregroundColor(FlightPlanColors.textSecondary)
                            }

                            // Signature and Date Grid
                            HStack(alignment: .top, spacing: 16) {
                                // Signature Box
                                VStack(alignment: .leading, spacing: 8) {
                                    GlassLabel(text: "Signature", required: true)

                                    Button {
                                        showSignaturePad = true
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.8))
                                                .frame(height: 80)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(signatureImage != nil ? FlightPlanColors.primary.opacity(0.5) : FlightPlanColors.border, lineWidth: 1)
                                                )

                                            if let signature = signatureImage {
                                                Image(uiImage: signature)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(height: 60)
                                                    .padding(.horizontal, 10)
                                            } else {
                                                VStack(spacing: 6) {
                                                    Image(systemName: "pencil.tip.crop.circle")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(FlightPlanColors.textMuted)
                                                    Text("Tap to sign")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(FlightPlanColors.textMuted)
                                                }
                                            }
                                        }
                                    }

                                    if signatureImage != nil {
                                        Button {
                                            signatureImage = nil
                                        } label: {
                                            Text("Clear signature")
                                                .font(.system(size: 11))
                                                .foregroundColor(FlightPlanColors.primary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                // Date Box
                                VStack(alignment: .leading, spacing: 8) {
                                    GlassLabel(text: "Date", required: true)

                                    Button {
                                        signatureDate = Date()
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.8))
                                                .frame(height: 80)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(signatureDate != nil ? FlightPlanColors.primary.opacity(0.5) : FlightPlanColors.border, lineWidth: 1)
                                                )

                                            if let date = signatureDate {
                                                VStack(spacing: 4) {
                                                    Text(formatSignatureDate(date))
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(FlightPlanColors.textPrimary)
                                                }
                                            } else {
                                                VStack(spacing: 6) {
                                                    Image(systemName: "calendar.badge.plus")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(FlightPlanColors.textMuted)
                                                    Text("Tap to add date")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(FlightPlanColors.textMuted)
                                                }
                                            }
                                        }
                                    }

                                    if signatureDate != nil {
                                        Button {
                                            signatureDate = nil
                                        } label: {
                                            Text("Clear date")
                                                .font(.system(size: 11))
                                                .foregroundColor(FlightPlanColors.primary)
                                        }
                                    }
                                }
                                .frame(width: 140)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Submit Button
                    Button(action: {
                        showGenerateConfirmation = true
                    }) {
                        ZStack {
                            if flightPlanService.isGeneratingPDF {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("SUBMIT FLIGHT PLAN")
                                    .font(.system(size: 13, weight: .semibold))
                                    .tracking(1.5)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Group {
                                if canSubmit {
                                    FlightPlanColors.primary
                                } else {
                                    Color.gray.opacity(0.5)
                                }
                            }
                        )
                        .cornerRadius(12)
                        .shadow(color: canSubmit ? FlightPlanColors.primary.opacity(0.25) : .clear, radius: 12, x: 0, y: 4)
                    }
                    .disabled(!canSubmit || flightPlanService.isGeneratingPDF)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .confirmationDialog("Generate Flight Plan", isPresented: $showGenerateConfirmation) {
            Button("Generate PDF") {
                generatePDF()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will generate a PDF document with your flight plan information.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("About Zulu Time", isPresented: $showZuluTimeInfo) {
            Button("OK") {}
        } message: {
            Text("Zulu time (Z) is the military and aviation term for UTC (Coordinated Universal Time). It's used globally to avoid confusion from different time zones.\n\nTo convert Zulu time to your local time:\n1. Note the Zulu time (e.g., 03:00:00)\n2. Apply your timezone offset from UTC\n3. For example, EST is UTC-5, so 03:00:00Z = 10:00 PM EST (previous day)\n\nThe local time is automatically displayed below for your convenience.")
        }
        .fullScreenCover(isPresented: $showPDFPreview) {
            if let pdfData = generatedPDFData {
                PDFPreviewView(
                    pdfData: pdfData,
                    pilotName: pilotName,
                    takeoffDateTime: takeoffDateTime,
                    onDismiss: { showPDFPreview = false },
                    onShare: {
                        showPDFPreview = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showShareSheet = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData = generatedPDFData {
                let pdfItem = PDFShareItem(data: pdfData, pilotName: pilotName, takeoffDateTime: takeoffDateTime)
                ShareSheet(items: [pdfItem])
            }
        }
        .sheet(isPresented: $showSignaturePad) {
            SignaturePadView(signatureImage: $signatureImage)
        }
        .sheet(isPresented: $showLAANCInfoSheet) {
            LAANCInfoSheet(
                airspaceClass: airspaceClass,
                hasLAANCCoverage: hasLAANCCoverage,
                laancGridCeiling: laancGridCeiling,
                requestedAltitude: maxAltitude,
                authorizationStatus: laancAuthorizationStatus
            )
        }
        .task {
            // Request location permission and start updates
            locationManager.requestPermission()
            locationManager.startLocationUpdates()

            // Fetch drone registrations
            if let pilotId = authService.currentUser?.id {
                await flightPlanService.fetchDroneRegistrations(pilotId: pilotId)
            }

            // Initialize from booking (only once)
            if !hasInitializedFromBooking {
                initializeFromBooking()
                hasInitializedFromBooking = true
            }
        }
    }

    // MARK: - Computed Properties

    private var pilotName: String {
        authService.userProfile?.fullName ?? "Unknown Pilot"
    }

    private var pilotCallSign: String {
        authService.userProfile?.callSign ?? "N/A"
    }

    private var takeoffDateTime: Date {
        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: takeoffDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: takeoffTime)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? Date()
    }

    private var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: takeoffDate)
    }

    private var zuluTimeString: String {
        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: takeoffDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: takeoffTime)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        guard let localDateTime = calendar.date(from: combined) else {
            return "--:--:--"
        }

        let zuluFormatter = DateFormatter()
        zuluFormatter.dateFormat = "HH:mm"
        zuluFormatter.timeZone = TimeZone(identifier: "UTC")

        return zuluFormatter.string(from: localDateTime)
    }

    private var localTimeString: String {
        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: takeoffDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: takeoffTime)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        guard let localDateTime = calendar.date(from: combined) else {
            return "Local: --:--"
        }

        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "h:mm a"
        localFormatter.timeZone = TimeZone.current

        // Get timezone abbreviation (e.g., EST, PST)
        let tzAbbrev = TimeZone.current.abbreviation() ?? "Local"

        return "\(tzAbbrev) \(localFormatter.string(from: localDateTime))"
    }

    private var canSubmit: Bool {
        let baseRequirements = selectedDrone != nil &&
            !location.isEmpty &&
            signatureImage != nil &&
            signatureDate != nil &&
            certificationRegulation != nil  // Regulation must be selected

        let flightOverPeopleValid = !flightOverPeople || !flightOverPeopleExplanation.isEmpty
        let part107Valid = part107Compliant || !part107NonComplianceExplanation.isEmpty
        let waiverValid = !requiresWaiver || (
            !waiverSafetyMitigations.isEmpty &&
            !waiverOperationalProcedures.isEmpty &&
            !waiverRiskAnalysis.isEmpty
        )

        return baseRequirements && flightOverPeopleValid && part107Valid && waiverValid
    }

    private func formatSignatureDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }

    private func droneDisplayName(_ drone: DroneRegistration) -> String {
        let manufacturer = drone.manufacturer ?? "Unknown"
        let model = drone.model ?? "Drone"
        return "\(manufacturer) \(model)"
    }

    // MARK: - Helper Methods

    private func useCurrentLocation() {
        guard let coordinate = locationManager.currentLocation else {
            errorMessage = "Unable to get current location. Please enable location services."
            showErrorAlert = true
            return
        }

        isGeocoding = true
        locationCoordinates = coordinate

        Task {
            if let address = await flightPlanService.reverseGeocodeLocation(coordinate) {
                await MainActor.run {
                    location = address
                    isGeocoding = false
                }
            } else {
                await MainActor.run {
                    location = "\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))"
                    isGeocoding = false
                }
            }
        }
    }

    private func generatePDF() {
        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: takeoffDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: takeoffTime)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        let takeoffDateTime = calendar.date(from: combined) ?? Date()

        let formData = FlightPlanFormData(
            pilotName: pilotName,
            callSign: pilotCallSign,
            droneManufacturer: selectedDrone?.manufacturer,
            droneModel: selectedDrone?.model,
            droneSerialNumber: selectedDrone?.serialNumber,
            droneRegistrationNumber: selectedDrone?.registrationNumber,
            takeoffDateTime: takeoffDateTime,
            location: location,
            latitude: locationCoordinates.map { String(format: "%.6f", $0.latitude) },
            longitude: locationCoordinates.map { String(format: "%.6f", $0.longitude) },
            regulatoryAuthority: regulatoryAuthority,
            maxAltitudeFeet: maxAltitude,
            airspaceClass: airspaceClass,
            laancGridCeiling: laancGridCeiling,
            laancAuthorizationStatus: laancAuthorizationStatus,
            flightOverPeople: flightOverPeople,
            flightOverPeopleExplanation: flightOverPeople ? flightOverPeopleExplanation : nil,
            vlosType: vlosType,
            part107Compliant: part107Compliant,
            part107NonComplianceExplanation: part107Compliant ? nil : part107NonComplianceExplanation,
            requiresWaiver: requiresWaiver,
            waiverSafetyMitigations: requiresWaiver ? waiverSafetyMitigations : nil,
            waiverOperationalProcedures: requiresWaiver ? waiverOperationalProcedures : nil,
            waiverRiskAnalysis: requiresWaiver ? waiverRiskAnalysis : nil,
            certificationRegulation: certificationRegulation!,  // Safe: canSubmit ensures this is not nil
            signatureImage: signatureImage,
            signatureDate: signatureDate,
            generatedAt: Date()
        )

        if let pdfData = flightPlanService.generatePDF(from: formData) {
            generatedPDFData = pdfData
            showPDFPreview = true
        } else {
            errorMessage = "Failed to generate PDF. Please try again."
            showErrorAlert = true
        }
    }

    private func initializeFromBooking() {
        // Set coordinates from booking
        locationCoordinates = CLLocationCoordinate2D(
            latitude: booking.locationLat,
            longitude: booking.locationLng
        )

        // Auto-populate date and time from booking's scheduled date
        if let scheduledDate = booking.scheduledDate {
            takeoffDate = scheduledDate
            takeoffTime = scheduledDate
        }

        // Reverse geocode to get the actual address from coordinates
        isGeocoding = true
        Task {
            // Fetch address and airspace data in parallel
            async let addressTask = flightPlanService.reverseGeocodeLocation(locationCoordinates!)
            async let airspaceTask: () = airspaceService.fetchAirspaceData(coordinate: locationCoordinates!)
            async let countryTask = detectCountryFromCoordinates(locationCoordinates!)

            let address = await addressTask
            await airspaceTask
            let detectedCountry = await countryTask

            await MainActor.run {
                if let address = address {
                    location = address
                } else {
                    // Fallback to coordinates if reverse geocoding fails
                    location = "\(String(format: "%.6f", booking.locationLat)), \(String(format: "%.6f", booking.locationLng))"
                }
                isGeocoding = false

                // Update local state from airspace service
                airspaceClass = airspaceService.airspaceClass
                laancGridCeiling = airspaceService.laancGridCeiling
                hasLAANCCoverage = airspaceService.hasLAANCCoverage

                // Set regulatory authority based on detected country (certification regulation requires manual selection)
                if let country = detectedCountry {
                    if country == "Canada" {
                        regulatoryAuthority = .transportCanada
                    } else {
                        regulatoryAuthority = .faa
                    }
                }

                // Calculate initial authorization status
                updateAuthorizationStatus()
            }
        }
    }

    private func detectCountryFromCoordinates(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first?.country
        } catch {
            print("Country detection failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func updateAuthorizationStatus() {
        laancAuthorizationStatus = airspaceService.calculateAuthorizationStatus(
            requestedAltitude: maxAltitude,
            laancCeiling: laancGridCeiling,
            airspaceClass: airspaceClass,
            hasLAANCCoverage: hasLAANCCoverage
        )
    }

    // MARK: - Address Search

    private func searchAddresses(query: String) {
        guard query.count >= 3 else {
            addressSuggestions = []
            showAddressSuggestions = false
            return
        }

        isSearchingAddress = true

        Task {
            let suggestions = await flightPlanService.searchAddresses(query: query)
            await MainActor.run {
                addressSuggestions = suggestions
                showAddressSuggestions = !suggestions.isEmpty
                isSearchingAddress = false
            }
        }
    }

    private func selectAddress(_ suggestion: AddressSuggestion) {
        location = suggestion.fullAddress
        locationCoordinates = suggestion.coordinate
        showAddressSuggestions = false
        addressSuggestions = []
    }
}

// MARK: - Address Search Models

struct AddressSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let fullAddress: String
    let coordinate: CLLocationCoordinate2D?
}

class AddressSearchDebouncer: ObservableObject {
    private var workItem: DispatchWorkItem?

    func search(query: String, action: @escaping (String) -> Void) {
        workItem?.cancel()

        let newWorkItem = DispatchWorkItem {
            action(query)
        }

        workItem = newWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: newWorkItem)
    }
}

// MARK: - PDF Share Item

class PDFShareItem: NSObject, UIActivityItemSource {
    let pdfData: Data
    let filename: String
    let fileURL: URL

    init(data: Data, pilotName: String, takeoffDateTime: Date) {
        self.pdfData = data

        // Format pilot name: replace spaces with underscores
        let formattedPilotName = pilotName.replacingOccurrences(of: " ", with: "_")

        // Format date: MMDDYY
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMddyy"
        let dateString = dateFormatter.string(from: takeoffDateTime)

        // Format time: HHMMSS
        dateFormatter.dateFormat = "HHmmss"
        let timeString = dateFormatter.string(from: takeoffDateTime)

        self.filename = "flight_plan_\(formattedPilotName)_\(dateString)_\(timeString).pdf"

        // Write PDF to temporary file with the correct filename
        let tempDir = FileManager.default.temporaryDirectory
        self.fileURL = tempDir.appendingPathComponent(self.filename)
        try? data.write(to: self.fileURL)
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileURL
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return fileURL
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Flight Plan"
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "com.adobe.pdf"
    }
}

// MARK: - PDF Preview View

struct PDFPreviewView: View {
    let pdfData: Data
    let pilotName: String
    let takeoffDateTime: Date
    let onDismiss: () -> Void
    let onShare: () -> Void

    var body: some View {
        NavigationView {
            PDFKitView(data: pdfData)
                .navigationTitle("Flight Plan Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            onDismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            onShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}

// MARK: - Glass Design Components

private struct GlassCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(FlightPlanColors.primary)
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(0.3)
                    .foregroundColor(FlightPlanColors.textPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle()
                    .fill(Color.white.opacity(0.5))
            )
            .overlay(
                Rectangle()
                    .fill(FlightPlanColors.borderLight)
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Card Content
            VStack(spacing: 0) {
                content
            }
            .padding(24)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FlightPlanColors.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 4)
                .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FlightPlanColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct GlassLabel: View {
    let text: String
    let required: Bool
    
    init(text: String, required: Bool = false) {
        self.text = text
        self.required = required
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(text.uppercased())
                .font(.system(size: 14, weight: .medium))
                .tracking(1.2)
                .foregroundColor(FlightPlanColors.textPrimary)
            
            if required {
                Text("*")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(FlightPlanColors.primary)
            }
        }
    }
}

private struct GlassReadOnlyField: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundColor(FlightPlanColors.textSecondary)
                
                Spacer()
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(FlightPlanColors.textMuted)
                }
            }
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(FlightPlanColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FlightPlanColors.fieldBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FlightPlanColors.borderLight, lineWidth: 1)
        )
    }
}

private struct GlassTextEditor: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let required: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassLabel(text: title, required: required)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundColor(FlightPlanColors.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(FlightPlanColors.textPrimary)
                    .frame(minHeight: 100)
                    .padding(12)
                    .scrollContentBackground(.hidden)
            }
            .background(Color.white.opacity(0.8))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FlightPlanColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Signature Drawing View

struct SignaturePadView: View {
    @Binding var signatureImage: UIImage?
    @State private var currentPath = Path()
    @State private var paths: [Path] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Instructions
                Text("Sign below using your finger")
                    .font(.system(size: 14))
                    .foregroundColor(FlightPlanColors.textSecondary)
                    .padding(.top, 16)

                // Signature canvas
                GeometryReader { geometry in
                    ZStack {
                        // Background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(FlightPlanColors.border, lineWidth: 2)
                            )

                        // Signature line
                        Path { path in
                            let y = geometry.size.height * 0.75
                            path.move(to: CGPoint(x: 20, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width - 20, y: y))
                        }
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                        // Draw existing paths
                        ForEach(paths.indices, id: \.self) { index in
                            paths[index]
                                .stroke(Color.black, lineWidth: 2)
                        }

                        // Draw current path
                        currentPath
                            .stroke(Color.black, lineWidth: 2)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let point = value.location
                                if currentPath.isEmpty {
                                    currentPath.move(to: point)
                                } else {
                                    currentPath.addLine(to: point)
                                }
                            }
                            .onEnded { _ in
                                paths.append(currentPath)
                                currentPath = Path()
                            }
                    )
                }
                .padding(20)
                .frame(height: 200)

                // Buttons
                HStack(spacing: 16) {
                    Button {
                        paths.removeAll()
                        currentPath = Path()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(FlightPlanColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(FlightPlanColors.border, lineWidth: 1)
                            )
                    }

                    Button {
                        saveSignature()
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(FlightPlanColors.primary)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(FlightPlanColors.background)
            .navigationTitle("Sign Here")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveSignature() {
        // Create image from paths
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 100))
        let image = renderer.image { ctx in
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.setLineCap(.round)
            ctx.cgContext.setLineJoin(.round)

            // Scale paths to fit the image
            let scaleX: CGFloat = 300 / UIScreen.main.bounds.width
            let scaleY: CGFloat = 100 / 200 // canvas height

            for path in paths {
                let cgPath = path.cgPath
                var transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                if let transformedPath = cgPath.copy(using: &transform) {
                    ctx.cgContext.addPath(transformedPath)
                }
            }
            ctx.cgContext.strokePath()
        }

        signatureImage = image
        dismiss()
    }
}

// MARK: - Checkbox Option

private struct CheckboxOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var isDisabled: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            if !isDisabled {
                action?()
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? FlightPlanColors.primary : FlightPlanColors.border, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? FlightPlanColors.primary : Color.white)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .opacity(isDisabled ? 0.6 : 1.0)

                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDisabled ? FlightPlanColors.textSecondary : FlightPlanColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(FlightPlanColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? FlightPlanColors.primary.opacity(0.08) : Color.white.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? FlightPlanColors.primary.opacity(0.3) : FlightPlanColors.border, lineWidth: 1)
            )
        }
        .disabled(isDisabled)
    }
}

// MARK: - Authorization Status Badge

private struct AuthorizationStatusBadge: View {
    let status: LAANCAuthorizationStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 14))
                .foregroundColor(statusColor)

            Text(status.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(statusColor)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(statusBackgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusIcon: String {
        switch status {
        case .autoApproved:
            return "checkmark.circle.fill"
        case .manualReviewRequired:
            return "clock.fill"
        case .noLAANCCoverage:
            return "exclamationmark.triangle.fill"
        case .notPermitted:
            return "xmark.circle.fill"
        case .pending:
            return "hourglass"
        case .notApplicable:
            return "minus.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .autoApproved:
            return Color.green
        case .manualReviewRequired:
            return Color.orange
        case .noLAANCCoverage:
            return Color.red
        case .notPermitted:
            return Color.red
        case .pending:
            return FlightPlanColors.textSecondary
        case .notApplicable:
            return FlightPlanColors.textSecondary
        }
    }

    private var statusBackgroundColor: Color {
        switch status {
        case .autoApproved:
            return Color.green.opacity(0.1)
        case .manualReviewRequired:
            return Color.orange.opacity(0.1)
        case .noLAANCCoverage:
            return Color.red.opacity(0.1)
        case .notPermitted:
            return Color.red.opacity(0.1)
        case .pending, .notApplicable:
            return FlightPlanColors.fieldBackground
        }
    }
}

// MARK: - LAANC Info Sheet

private struct LAANCInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let airspaceClass: AirspaceClass
    let hasLAANCCoverage: Bool
    let laancGridCeiling: Int?
    let requestedAltitude: Int
    let authorizationStatus: LAANCAuthorizationStatus

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Current Status Section
                    currentStatusSection

                    Divider()

                    // Decision Tree Section
                    decisionTreeSection

                    Divider()

                    // Your Situation Section
                    yourSituationSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("LAANC Authorization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current Status", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(FlightPlanColors.primary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Airspace Class:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(airspaceClass == .unknown ? "Unknown" : "Class \(airspaceClass.rawValue)")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("LAANC Coverage:")
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: hasLAANCCoverage ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(hasLAANCCoverage ? .green : .red)
                        Text(hasLAANCCoverage ? "Yes" : "No")
                            .fontWeight(.medium)
                    }
                }

                if let ceiling = laancGridCeiling {
                    HStack {
                        Text("LAANC Grid Ceiling:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(ceiling) ft AGL")
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    Text("Requested Altitude:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(requestedAltitude) ft AGL")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Authorization Status:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(authorizationStatus.rawValue)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    private var decisionTreeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How Authorization is Determined", systemImage: "arrow.triangle.branch")
                .font(.headline)
                .foregroundColor(FlightPlanColors.primary)

            VStack(alignment: .leading, spacing: 16) {
                // Step 1
                decisionStep(
                    number: 1,
                    title: "Query UASFM (LAANC Grid)",
                    description: "First, we check if your location has LAANC auto-approval coverage.",
                    outcomes: [
                        ("Got a result? YES", "Use that altitude as the auto-approval ceiling.", true),
                        ("Got a result? NO", "Proceed to Step 2.", false)
                    ]
                )

                // Step 2
                decisionStep(
                    number: 2,
                    title: "Query Class Airspace",
                    description: "If no LAANC grid data exists, we check the airspace classification.",
                    outcomes: [
                        ("Class G (uncontrolled)", "No authorization needed. Safe to fly under Part 107 rules.", true),
                        ("Class B / C / D / E (controlled)", "Controlled airspace with NO LAANC auto-approval. Must use manual FAA DroneZone authorization.", false)
                    ]
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    private func decisionStep(number: Int, title: String, description: String, outcomes: [(String, String, Bool)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(FlightPlanColors.primary)
                    .clipShape(Circle())

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 34)

            ForEach(outcomes.indices, id: \.self) { index in
                let outcome = outcomes[index]
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(outcome.0)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(outcome.1)
                            .font(.caption2)
                            .foregroundColor(outcome.2 ? .green : .orange)
                    }
                }
            }
        }
    }

    private var yourSituationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Situation", systemImage: "location.fill")
                .font(.headline)
                .foregroundColor(FlightPlanColors.primary)

            VStack(alignment: .leading, spacing: 8) {
                Text(situationExplanation)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                if authorizationStatus == .noLAANCCoverage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("You must obtain manual authorization via FAA DroneZone before flying.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                if authorizationStatus == .manualReviewRequired {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Your requested altitude exceeds the LAANC auto-approval ceiling. You may request higher altitude through LAANC manual review or FAA DroneZone.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    private var situationExplanation: String {
        switch authorizationStatus {
        case .autoApproved:
            if let ceiling = laancGridCeiling {
                return "Your location is in controlled airspace with LAANC coverage. Your requested altitude of \(requestedAltitude) ft is within the auto-approval ceiling of \(ceiling) ft. You can fly without additional authorization."
            }
            return "Your flight is auto-approved under current conditions."

        case .manualReviewRequired:
            if let ceiling = laancGridCeiling {
                return "Your location has LAANC coverage with a ceiling of \(ceiling) ft, but your requested altitude of \(requestedAltitude) ft exceeds this limit."
            }
            return "Manual review is required for your requested flight parameters."

        case .noLAANCCoverage:
            return "Your location is in Class \(airspaceClass.rawValue) controlled airspace, but there is no LAANC auto-approval coverage at this location. This typically occurs at smaller airports or areas just outside LAANC grid boundaries."

        case .notPermitted:
            return "Your requested altitude of \(requestedAltitude) ft exceeds the 400 ft AGL limit allowed under Part 107. This altitude is not permitted without a waiver."

        case .notApplicable:
            return "Your location is in Class G (uncontrolled) airspace. No LAANC authorization is needed. You may fly under standard Part 107 rules (below 400 ft AGL, visual line of sight, etc.)."

        case .pending:
            return "Authorization status is being determined..."
        }
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .autoApproved: return .green
        case .manualReviewRequired: return .orange
        case .noLAANCCoverage, .notPermitted: return .red
        case .pending, .notApplicable: return .secondary
        }
    }
}
