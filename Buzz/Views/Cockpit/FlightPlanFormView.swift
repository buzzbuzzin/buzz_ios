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
    @State private var generatedPDFData: Data?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isGeocoding = false
    @State private var weatherLoadingState: WeatherLoadingState = .notLoaded

    enum WeatherLoadingState {
        case notLoaded
        case loading
        case loaded
        case unavailable
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flight Plan & Site Survey")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Complete the flight plan details and site survey information. Weather conditions will be automatically populated based on your selected date and time.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

                // Flight Plan Section
                FlightPlanFormSection(title: "Flight Plan") {
                    VStack(spacing: 16) {
                        // Pilot Name - Read-only, auto-filled
                        ReadOnlyFormField(
                            title: "Pilot Name",
                            value: pilotName
                        )

                        // Callsign - Read-only, auto-filled
                        ReadOnlyFormField(
                            title: "Callsign",
                            value: pilotCallSign
                        )

                        // Drone Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Drone *")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if flightPlanService.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading drones...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            } else if flightPlanService.registrations.isEmpty {
                                Text("No drones registered. Please register a drone first.")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
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
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("Select a drone")
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            }
                        }

                        // Takeoff Date
                        FlightPlanDatePicker(
                            title: "Takeoff Date *",
                            date: $takeoffDate
                        )

                        // Takeoff Time
                        FlightPlanTimePicker(
                            title: "Takeoff Time *",
                            time: $takeoffTime
                        )

                        // Location with current location button
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location *")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                TextField("Enter location or use current", text: $location)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())

                                Button(action: useCurrentLocation) {
                                    if isGeocoding {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .disabled(isGeocoding)
                                .frame(width: 40, height: 40)
                            }

                            if let coords = locationCoordinates {
                                Text("Coordinates: \(String(format: "%.6f", coords.latitude)), \(String(format: "%.6f", coords.longitude))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Site Survey Section
                FlightPlanFormSection(title: "Site Survey") {
                    VStack(spacing: 16) {
                        FlightPlanTextEditor(
                            title: "1. Operation Boundaries *",
                            text: $operationBoundaries,
                            placeholder: "Define the geographic boundaries of your operation area"
                        )

                        FlightPlanTextEditor(
                            title: "2. Airspace and Requirements *",
                            text: $airspaceAndRequirements,
                            placeholder: "Describe airspace classification and any authorization requirements"
                        )

                        FlightPlanTextEditor(
                            title: "3. Altitudes and Routes *",
                            text: $altitudesAndRoutes,
                            placeholder: "Specify planned flight altitudes and routes"
                        )

                        FlightPlanTextEditor(
                            title: "4. Proximity of Manned Aircraft Operations *",
                            text: $proximityMannedAircraft,
                            placeholder: "Identify nearby manned aircraft activity and mitigations"
                        )

                        FlightPlanTextEditor(
                            title: "5. Proximity of Aerodromes and Helicopters *",
                            text: $proximityAerodromes,
                            placeholder: "List nearby airports, heliports, and associated considerations"
                        )

                        FlightPlanTextEditor(
                            title: "6. Obstacle Locations and Heights *",
                            text: $obstacleLocationsHeights,
                            placeholder: "Document obstacles such as towers, buildings, power lines"
                        )

                        // Weather Conditions - Auto-populated
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("7. Weather Conditions")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Spacer()

                                switch weatherLoadingState {
                                case .loading:
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                        Text("Loading...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                case .loaded:
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Auto-populated")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                case .unavailable:
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("Beyond forecast range")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                case .notLoaded:
                                    EmptyView()
                                }
                            }

                            if weatherConditions.isEmpty {
                                Text("Weather will be populated when location and date/time are set")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            } else {
                                Text(weatherConditions)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                        }

                        FlightPlanTextEditor(
                            title: "8. Horizontal Distance and Bystanders *",
                            text: $horizontalDistanceBystanders,
                            placeholder: "Describe minimum distances to people and property"
                        )

                        FlightPlanTextEditor(
                            title: "9. Notes (Optional)",
                            text: $notes,
                            placeholder: "Any additional notes or considerations"
                        )
                    }
                }

                // Generate Form Button
                Button(action: {
                    showGenerateConfirmation = true
                }) {
                    HStack {
                        if flightPlanService.isGeneratingPDF {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "doc.fill")
                            Text("Generate Form")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSubmit ? Color.indigo : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit || flightPlanService.isGeneratingPDF)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Flight Plan")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
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
        .sheet(isPresented: $showShareSheet) {
            if let pdfData = generatedPDFData {
                ShareSheet(items: [pdfData])
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
            showShareSheet = true
        } else {
            errorMessage = "Failed to generate PDF. Please try again."
            showErrorAlert = true
        }
    }
}

// MARK: - Form Components

private struct FlightPlanFormSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                content
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

private struct ReadOnlyFormField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }
}

private struct FlightPlanDatePicker: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            DatePicker("", selection: $date, displayedComponents: [.date])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FlightPlanTimePicker: View {
    let title: String
    @Binding var time: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            DatePicker("", selection: $time, displayedComponents: [.hourAndMinute])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FlightPlanTextEditor: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $text)
                    .frame(minHeight: 80)
                    .padding(4)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}
