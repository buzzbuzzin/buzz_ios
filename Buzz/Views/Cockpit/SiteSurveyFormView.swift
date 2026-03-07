//
//  SiteSurveyFormView.swift
//  Buzz
//
//  Created for site survey form
//

import SwiftUI
import CoreLocation
import Combine
import Auth
import PDFKit

// MARK: - Design System Colors
private struct SiteSurveyColors {
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

struct SiteSurveyFormView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var safeFlyService = SafeFlyService()
    @StateObject private var locationManager = BookingMapLocationManager()
    @StateObject private var siteSurveyService = SiteSurveyService()
    @Environment(\.dismiss) private var dismiss

    // Optional booking for auto-populating location
    let booking: Booking?
    let isEmbedded: Bool
    
    init(booking: Booking? = nil, isEmbedded: Bool = false) {
        self.booking = booking
        self.isEmbedded = isEmbedded
    }

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

    // Location fields (optional, for weather)
    @State private var location: String = ""
    @State private var locationCoordinates: CLLocationCoordinate2D?
    @State private var hasLoadedBookingLocation = false

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
                    // Custom Header - only show if NOT embedded in tab
                    if !isEmbedded {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(SiteSurveyColors.textSecondary)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.8))
                                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(SiteSurveyColors.border, lineWidth: 1)
                                    )
                            }

                            Spacer()

                            Text("Site Survey")
                                .font(.system(size: 18, weight: .semibold))
                                .tracking(0.3)
                                .foregroundColor(SiteSurveyColors.textPrimary)

                            Spacer()

                            // Spacer for centering
                            Color.clear
                                .frame(width: 40, height: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // Location Section (Optional - for weather auto-population)
                    SiteSurveyGlassCard(title: "Location (Optional)", icon: "mappin.circle") {
                        VStack(spacing: 20) {
                            Text("Add a location to auto-populate weather conditions")
                                .font(.system(size: 14))
                                .foregroundColor(SiteSurveyColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Location with address autocomplete
                            VStack(alignment: .leading, spacing: 8) {
                                SiteSurveyGlassLabel(text: "Location", required: false)

                                HStack(spacing: 0) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(SiteSurveyColors.textSecondary)
                                        .padding(.leading, 14)

                                    TextField("Enter address or coordinates", text: $location)
                                        .font(.system(size: 15))
                                        .foregroundColor(SiteSurveyColors.textPrimary)
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
                                                .foregroundColor(SiteSurveyColors.primary)
                                        }
                                    }
                                    .disabled(isGeocoding)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(SiteSurveyColors.primary.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.trailing, 8)
                                }
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(SiteSurveyColors.border, lineWidth: 1)
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
                                                        .foregroundColor(SiteSurveyColors.textPrimary)
                                                    if let subtitle = suggestion.subtitle {
                                                        Text(subtitle)
                                                            .font(.caption)
                                                            .foregroundColor(SiteSurveyColors.textSecondary)
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
                                            .stroke(SiteSurveyColors.border, lineWidth: 1)
                                    )
                                }

                                if isSearchingAddress {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                        Text("Searching...")
                                            .font(.caption)
                                            .foregroundColor(SiteSurveyColors.textSecondary)
                                    }
                                }

                                if let coords = locationCoordinates {
                                    Text("Coordinates: \(String(format: "%.6f", coords.latitude)), \(String(format: "%.6f", coords.longitude))")
                                        .font(.caption)
                                        .foregroundColor(SiteSurveyColors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Site Survey Section
                    SiteSurveyGlassCard(title: "Site Survey", icon: "doc.text") {
                        VStack(spacing: 20) {
                            SiteSurveyGlassTextEditor(
                                title: "1. Operation Boundaries",
                                text: $operationBoundaries,
                                placeholder: "Define the geographic boundaries of your operation area...",
                                required: true
                            )

                            SiteSurveyGlassTextEditor(
                                title: "2. Airspace and Requirements",
                                text: $airspaceAndRequirements,
                                placeholder: "Describe airspace classification and any authorization requirements...",
                                required: true
                            )

                            SiteSurveyGlassTextEditor(
                                title: "3. Altitudes and Routes",
                                text: $altitudesAndRoutes,
                                placeholder: "Specify planned flight altitudes and routes...",
                                required: true
                            )

                            SiteSurveyGlassTextEditor(
                                title: "4. Proximity of Manned Aircraft Operations",
                                text: $proximityMannedAircraft,
                                placeholder: "Identify nearby manned aircraft activity and mitigations...",
                                required: true
                            )

                            SiteSurveyGlassTextEditor(
                                title: "5. Proximity of Aerodromes and Helicopters",
                                text: $proximityAerodromes,
                                placeholder: "List nearby airports, heliports, and associated considerations...",
                                required: true
                            )

                            SiteSurveyGlassTextEditor(
                                title: "6. Obstacle Locations and Heights",
                                text: $obstacleLocationsHeights,
                                placeholder: "Document obstacles such as towers, buildings, power lines...",
                                required: true
                            )

                            // Weather Conditions - Auto-populated
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    SiteSurveyGlassLabel(text: "7. Weather Conditions", required: false)

                                    Spacer()

                                    switch weatherLoadingState {
                                    case .loading:
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                            Text("Loading...")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(SiteSurveyColors.textSecondary)
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
                                    Text("Weather will be populated when location is set")
                                        .font(.system(size: 14))
                                        .foregroundColor(SiteSurveyColors.textMuted)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(SiteSurveyColors.border, lineWidth: 1)
                                        )
                                } else {
                                    Text(weatherConditions)
                                        .font(.system(size: 14))
                                        .foregroundColor(SiteSurveyColors.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(SiteSurveyColors.border, lineWidth: 1)
                                        )
                                }
                            }

                            SiteSurveyGlassTextEditor(
                                title: "8. Horizontal Distance and Bystanders",
                                text: $horizontalDistanceBystanders,
                                placeholder: "Describe minimum distances to people and property...",
                                required: true
                            )

                            SiteSurveyGlassTextEditor(
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
                            if siteSurveyService.isGeneratingPDF {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("GENERATE SITE SURVEY")
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
                                    SiteSurveyColors.primary
                                } else {
                                    Color.gray.opacity(0.5)
                                }
                            }
                        )
                        .cornerRadius(12)
                        .shadow(color: canSubmit ? SiteSurveyColors.primary.opacity(0.25) : .clear, radius: 12, x: 0, y: 4)
                    }
                    .disabled(!canSubmit || siteSurveyService.isGeneratingPDF)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(!isEmbedded) // Only hide navigation bar when NOT embedded
        .confirmationDialog("Generate Site Survey", isPresented: $showGenerateConfirmation) {
            Button("Generate PDF") {
                generatePDF()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will generate a PDF document with your site survey information.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showPDFPreview) {
            if let pdfData = generatedPDFData {
                SiteSurveyPDFPreviewView(
                    pdfData: pdfData,
                    pilotName: pilotDisplayName,
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
                let pdfItem = SiteSurveyPDFShareItem(data: pdfData, pilotName: pilotDisplayName)
                ShareSheet(items: [pdfItem])
            }
        }
        .task {
            // Load booking location if available
            if let booking = booking, !hasLoadedBookingLocation {
                await loadBookingLocation()
                hasLoadedBookingLocation = true
            }
            
            // Request location permission and start updates
            locationManager.requestPermission()
            locationManager.startLocationUpdates()
        }
        .onReceive(locationManager.$currentLocation.compactMap { $0 }) { newLocation in
            if safeFlyService.hourlyForecasts.isEmpty && locationCoordinates != nil {
                Task {
                    await safeFlyService.fetchSafeFlyData(coordinate: newLocation)
                    updateWeatherForCurrentTime()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var pilotDisplayName: String {
        authService.userProfile?.publicPilotName ?? "Pilot"
    }

    private var canSubmit: Bool {
        !operationBoundaries.isEmpty &&
        !airspaceAndRequirements.isEmpty &&
        !altitudesAndRoutes.isEmpty &&
        !proximityMannedAircraft.isEmpty &&
        !proximityAerodromes.isEmpty &&
        !obstacleLocationsHeights.isEmpty &&
        !horizontalDistanceBystanders.isEmpty
    }

    // MARK: - Helper Methods

    private func loadBookingLocation() async {
        guard let booking = booking else { return }
        
        // Set coordinates from booking
        let coordinate = CLLocationCoordinate2D(
            latitude: booking.locationLat,
            longitude: booking.locationLng
        )
        locationCoordinates = coordinate
        
        // Reverse geocode to get the full address
        if let address = await siteSurveyService.reverseGeocodeLocation(coordinate) {
            await MainActor.run {
                location = address
            }
        } else {
            // Fall back to booking's location name if reverse geocoding fails
            await MainActor.run {
                location = booking.locationName
            }
        }
        
        // Fetch weather for this location
        await safeFlyService.fetchSafeFlyData(coordinate: coordinate)
        updateWeatherForCurrentTime()
    }

    private func useCurrentLocation() {
        guard let coordinate = locationManager.currentLocation else {
            errorMessage = "Unable to get current location. Please enable location services."
            showErrorAlert = true
            return
        }

        isGeocoding = true
        locationCoordinates = coordinate

        Task {
            if let address = await siteSurveyService.reverseGeocodeLocation(coordinate) {
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
            updateWeatherForCurrentTime()
        }
    }

    private func updateWeatherForCurrentTime() {
        weatherLoadingState = .loading

        let currentDateTime = Date()

        if let weather = siteSurveyService.formatWeatherForDateTime(from: safeFlyService.hourlyForecasts, dateTime: currentDateTime) {
            weatherConditions = weather
            weatherLoadingState = .loaded
        } else if safeFlyService.hourlyForecasts.isEmpty {
            weatherConditions = ""
            weatherLoadingState = .notLoaded
        } else {
            weatherConditions = "Weather forecast not available"
            weatherLoadingState = .unavailable
        }
    }

    private func generatePDF() {
        let formData = SiteSurveyFormData(
            operationBoundaries: operationBoundaries,
            airspaceAndRequirements: airspaceAndRequirements,
            altitudesAndRoutes: altitudesAndRoutes,
            proximityMannedAircraft: proximityMannedAircraft,
            proximityAerodromes: proximityAerodromes,
            obstacleLocationsHeights: obstacleLocationsHeights,
            weatherConditions: weatherConditions.isEmpty ? "Not available" : weatherConditions,
            horizontalDistanceBystanders: horizontalDistanceBystanders,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            locationCoordinates: locationCoordinates.map { "\(String(format: "%.6f", $0.latitude)), \(String(format: "%.6f", $0.longitude))" },
            pilotName: pilotDisplayName,
            generatedAt: Date()
        )

        if let pdfData = siteSurveyService.generatePDF(from: formData) {
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
            let suggestions = await siteSurveyService.searchAddresses(query: query)
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
                updateWeatherForCurrentTime()
            }
        }
    }
}

// MARK: - PDF Share Item

class SiteSurveyPDFShareItem: NSObject, UIActivityItemSource {
    let pdfData: Data
    let filename: String
    let fileURL: URL

    init(data: Data, pilotName: String) {
        self.pdfData = data

        // Format pilot name: replace spaces with underscores
        let formattedPilotName = pilotName.replacingOccurrences(of: " ", with: "_")

        // Format date: MMDDYY
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMddyy"
        let dateString = dateFormatter.string(from: Date())

        // Format time: HHMMSS
        dateFormatter.dateFormat = "HHmmss"
        let timeString = dateFormatter.string(from: Date())

        self.filename = "site_survey_\(formattedPilotName)_\(dateString)_\(timeString).pdf"

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
        return "Site Survey"
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "com.adobe.pdf"
    }
}

// MARK: - PDF Preview View

struct SiteSurveyPDFPreviewView: View {
    let pdfData: Data
    let pilotName: String
    let onDismiss: () -> Void
    let onShare: () -> Void

    var body: some View {
        NavigationView {
            SiteSurveyPDFKitView(data: pdfData)
                .navigationTitle("Site Survey Preview")
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

struct SiteSurveyPDFKitView: UIViewRepresentable {
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

private struct SiteSurveyGlassCard<Content: View>: View {
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
                    .foregroundColor(SiteSurveyColors.primary)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(0.3)
                    .foregroundColor(SiteSurveyColors.textPrimary)
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
                    .fill(SiteSurveyColors.borderLight)
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
                .fill(SiteSurveyColors.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 4)
                .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SiteSurveyColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SiteSurveyGlassLabel: View {
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
                .foregroundColor(SiteSurveyColors.textPrimary)

            if required {
                Text("*")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(SiteSurveyColors.primary)
            }
        }
    }
}

private struct SiteSurveyGlassTextEditor: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let required: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SiteSurveyGlassLabel(text: title, required: required)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundColor(SiteSurveyColors.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(SiteSurveyColors.textPrimary)
                    .frame(minHeight: 100)
                    .padding(12)
                    .scrollContentBackground(.hidden)
            }
            .background(Color.white.opacity(0.8))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SiteSurveyColors.border, lineWidth: 1)
            )
        }
    }
}
