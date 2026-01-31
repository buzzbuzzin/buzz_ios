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
    @StateObject private var safeFlyService = SafeFlyService()
    @StateObject private var locationManager = BookingMapLocationManager()
    @Environment(\.dismiss) private var dismiss

    // Flight Plan Section Fields
    @State private var selectedDrone: DroneRegistration?
    @State private var takeoffDate = Date()
    @State private var takeoffTime = Date()
    @State private var location: String = ""
    @State private var locationCoordinates: CLLocationCoordinate2D?

    // Site Survey Section Fields
    @State private var operationBoundaries: String = ""
    @State private var airspaceAndRequirements: String = ""
    @State private var altitudesAndRoutes: String = ""
    @State private var proximityMannedAircraft: String = ""
    @State private var proximityAerodromes: String = ""
    @State private var obstacleLocationsHeights: String = ""
    @State private var weatherConditions: String = ""
    @State private var horizontalDistanceBystanders: String = ""
    @State private var notes: String = ""

    // UI State
    @State private var showGenerateConfirmation = false
    @State private var showShareSheet = false
    @State private var showPDFPreview = false
    @State private var generatedPDFData: Data?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isGeocoding = false
    @State private var weatherLoadingState: WeatherLoadingState = .notLoaded

    // Address autocomplete
    @State private var addressSuggestions: [AddressSuggestion] = []
    @State private var isSearchingAddress = false
    @State private var showAddressSuggestions = false
    @StateObject private var addressSearchDebouncer = AddressSearchDebouncer()

    enum WeatherLoadingState {
        case notLoaded
        case loading
        case loaded
        case unavailable
    }

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
                                // Takeoff Date
                                VStack(alignment: .leading, spacing: 8) {
                                    GlassLabel(text: "Takeoff Date", required: true)

                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14))
                                            .foregroundColor(FlightPlanColors.primary)

                                        DatePicker("", selection: $takeoffDate, displayedComponents: [.date])
                                            .labelsHidden()
                                            .datePickerStyle(.compact)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(FlightPlanColors.border, lineWidth: 1)
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Takeoff Time and Zulu Time
                                VStack(alignment: .leading, spacing: 8) {
                                    GlassLabel(text: "Takeoff Time", required: true)

                                    HStack(spacing: 8) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 14))
                                            .foregroundColor(FlightPlanColors.primary)

                                        DatePicker("", selection: $takeoffTime, displayedComponents: [.hourAndMinute])
                                            .labelsHidden()
                                            .datePickerStyle(.compact)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(FlightPlanColors.border, lineWidth: 1)
                                    )

                                    // Zulu time aligned to the left
                                    Text(zuluTimeString.uppercased())
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(0.5)
                                        .foregroundColor(FlightPlanColors.textSecondary)
                                        .padding(.leading, 12)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Location with address autocomplete
                            VStack(alignment: .leading, spacing: 8) {
                                GlassLabel(text: "Location", required: true)

                                HStack(spacing: 0) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(FlightPlanColors.textSecondary)
                                        .padding(.leading, 14)
                                    
                                    TextField("Enter address or coordinates", text: $location)
                                        .font(.system(size: 15))
                                        .foregroundColor(FlightPlanColors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 14)
                                        .onChange(of: location) { newValue in
                                            addressSearchDebouncer.search(query: newValue) { query in
                                                searchAddresses(query: query)
                                            }
                                        }
                                        .onTapGesture {
                                            if !addressSuggestions.isEmpty {
                                                showAddressSuggestions = true
                                            }
                                        }
                                    
                                    Button(action: useCurrentLocation) {
                                        if isGeocoding {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(FlightPlanColors.primary)
                                        }
                                    }
                                    .disabled(isGeocoding)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(FlightPlanColors.primary.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.trailing, 8)
                                }
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(FlightPlanColors.border, lineWidth: 1)
                                )

                                // Address suggestions dropdown
                                if showAddressSuggestions && !addressSuggestions.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(addressSuggestions) { suggestion in
                                            Button {
                                                selectAddress(suggestion)
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(suggestion.title)
                                                        .font(.subheadline)
                                                        .foregroundColor(FlightPlanColors.textPrimary)
                                                    if let subtitle = suggestion.subtitle {
                                                        Text(subtitle)
                                                            .font(.caption)
                                                            .foregroundColor(FlightPlanColors.textSecondary)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                            }
                                            if suggestion.id != addressSuggestions.last?.id {
                                                Divider()
                                                    .padding(.horizontal, 12)
                                            }
                                        }
                                    }
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(FlightPlanColors.border, lineWidth: 1)
                                    )
                                }

                                if isSearchingAddress {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                        Text("Searching...")
                                            .font(.caption)
                                            .foregroundColor(FlightPlanColors.textSecondary)
                                    }
                                }

                                if let coords = locationCoordinates {
                                    Text("Coordinates: \(String(format: "%.6f", coords.latitude)), \(String(format: "%.6f", coords.longitude))")
                                        .font(.caption)
                                        .foregroundColor(FlightPlanColors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Site Survey Section
                    GlassCard(title: "Site Survey", icon: "doc.text") {
                        VStack(spacing: 20) {
                            GlassTextEditor(
                                title: "1. Operation Boundaries",
                                text: $operationBoundaries,
                                placeholder: "Define the geographic boundaries of your operation area...",
                                required: true
                            )

                            GlassTextEditor(
                                title: "2. Airspace and Requirements",
                                text: $airspaceAndRequirements,
                                placeholder: "Describe airspace classification and any authorization requirements...",
                                required: true
                            )

                            GlassTextEditor(
                                title: "3. Altitudes and Routes",
                                text: $altitudesAndRoutes,
                                placeholder: "Specify planned flight altitudes and routes...",
                                required: true
                            )

                            GlassTextEditor(
                                title: "4. Proximity of Manned Aircraft Operations",
                                text: $proximityMannedAircraft,
                                placeholder: "Identify nearby manned aircraft activity and mitigations...",
                                required: true
                            )

                            GlassTextEditor(
                                title: "5. Proximity of Aerodromes and Helicopters",
                                text: $proximityAerodromes,
                                placeholder: "List nearby airports, heliports, and associated considerations...",
                                required: true
                            )

                            GlassTextEditor(
                                title: "6. Obstacle Locations and Heights",
                                text: $obstacleLocationsHeights,
                                placeholder: "Document obstacles such as towers, buildings, power lines...",
                                required: true
                            )

                            // Weather Conditions - Auto-populated
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    GlassLabel(text: "7. Weather Conditions", required: false)

                                    Spacer()

                                    switch weatherLoadingState {
                                    case .loading:
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                            Text("Loading...")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(FlightPlanColors.textSecondary)
                                        }
                                    case .loaded:
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 12))
                                            Text("Auto-populated")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.green)
                                        }
                                    case .unavailable:
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 12))
                                            Text("Beyond range")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.orange)
                                        }
                                    case .notLoaded:
                                        EmptyView()
                                    }
                                }

                                if weatherConditions.isEmpty {
                                    Text("Weather will be populated when location and date/time are set")
                                        .font(.system(size: 14))
                                        .foregroundColor(FlightPlanColors.textMuted)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(FlightPlanColors.border, lineWidth: 1)
                                        )
                                } else {
                                    Text(weatherConditions)
                                        .font(.system(size: 14))
                                        .foregroundColor(FlightPlanColors.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(FlightPlanColors.border, lineWidth: 1)
                                        )
                                }
                            }

                            GlassTextEditor(
                                title: "8. Horizontal Distance and Bystanders",
                                text: $horizontalDistanceBystanders,
                                placeholder: "Describe minimum distances to people and property...",
                                required: true
                            )

                            GlassTextEditor(
                                title: "9. Notes (Optional)",
                                text: $notes,
                                placeholder: "Any additional notes or considerations...",
                                required: false
                            )
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
            Text("This will generate a PDF document with your flight plan and site survey information.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
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
        .task {
            // Request location permission and start updates
            locationManager.requestPermission()
            locationManager.startLocationUpdates()

            // Fetch drone registrations
            if let pilotId = authService.currentUser?.id {
                await flightPlanService.fetchDroneRegistrations(pilotId: pilotId)
            }

            // Fetch initial weather data
            await fetchWeatherData()
        }
        .onChange(of: takeoffDate) { _ in
            updateWeatherForSelectedDateTime()
        }
        .onChange(of: takeoffTime) { _ in
            updateWeatherForSelectedDateTime()
        }
        .onReceive(locationManager.$currentLocation.compactMap { $0 }) { newLocation in
            if safeFlyService.hourlyForecasts.isEmpty {
                Task {
                    await safeFlyService.fetchSafeFlyData(coordinate: newLocation)
                    updateWeatherForSelectedDateTime()
                }
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
            return "Zulu: ----Z"
        }

        let zuluFormatter = DateFormatter()
        zuluFormatter.dateFormat = "ddHHmm"
        zuluFormatter.timeZone = TimeZone(identifier: "UTC")

        return "Zulu: \(zuluFormatter.string(from: localDateTime))Z"
    }

    private var canSubmit: Bool {
        selectedDrone != nil &&
        !location.isEmpty &&
        !operationBoundaries.isEmpty &&
        !airspaceAndRequirements.isEmpty &&
        !altitudesAndRoutes.isEmpty &&
        !proximityMannedAircraft.isEmpty &&
        !proximityAerodromes.isEmpty &&
        !obstacleLocationsHeights.isEmpty &&
        !horizontalDistanceBystanders.isEmpty
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

            // Fetch weather for this location
            await safeFlyService.fetchSafeFlyData(coordinate: coordinate)
            updateWeatherForSelectedDateTime()
        }
    }

    private func fetchWeatherData() async {
        if let coordinate = locationManager.currentLocation {
            await safeFlyService.fetchSafeFlyData(coordinate: coordinate)
            updateWeatherForSelectedDateTime()
        }
    }

    private func updateWeatherForSelectedDateTime() {
        weatherLoadingState = .loading

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

        guard let selectedDateTime = calendar.date(from: combined) else {
            weatherLoadingState = .unavailable
            return
        }

        if let weather = flightPlanService.formatWeatherForDateTime(from: safeFlyService.hourlyForecasts, dateTime: selectedDateTime) {
            weatherConditions = weather
            weatherLoadingState = .loaded
        } else if safeFlyService.hourlyForecasts.isEmpty {
            weatherConditions = ""
            weatherLoadingState = .notLoaded
        } else {
            weatherConditions = "Weather forecast not available for selected date/time (beyond 48-hour forecast range)"
            weatherLoadingState = .unavailable
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
            locationCoordinates: locationCoordinates.map { "\(String(format: "%.6f", $0.latitude)), \(String(format: "%.6f", $0.longitude))" },
            operationBoundaries: operationBoundaries,
            airspaceAndRequirements: airspaceAndRequirements,
            altitudesAndRoutes: altitudesAndRoutes,
            proximityMannedAircraft: proximityMannedAircraft,
            proximityAerodromes: proximityAerodromes,
            obstacleLocationsHeights: obstacleLocationsHeights,
            weatherConditions: weatherConditions.isEmpty ? "Not available" : weatherConditions,
            horizontalDistanceBystanders: horizontalDistanceBystanders,
            notes: notes.isEmpty ? nil : notes,
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

        // Fetch weather for this location if we have coordinates
        if let coordinate = suggestion.coordinate {
            Task {
                await safeFlyService.fetchSafeFlyData(coordinate: coordinate)
                updateWeatherForSelectedDateTime()
            }
        }
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
        return "Flight Plan & Site Survey"
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
