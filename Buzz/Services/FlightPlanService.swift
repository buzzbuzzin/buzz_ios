//
//  FlightPlanService.swift
//  Buzz
//
//  Created for flight plan PDF generation
//

import Foundation
import Supabase
import UIKit
import CoreLocation
import Combine
import SwiftUI

@MainActor
class FlightPlanService: ObservableObject {
    @Published var registrations: [DroneRegistration] = []
    @Published var isLoading = false
    @Published var isGeneratingPDF = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client

    // MARK: - Fetch Drone Registrations

    func fetchDroneRegistrations(pilotId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let registrations: [DroneRegistration] = try await supabase
                .from("drone_registrations")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("uploaded_at", ascending: false)
                .execute()
                .value

            self.registrations = registrations
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            print("Error fetching drone registrations: \(error.localizedDescription)")
        }
    }

    // MARK: - Format Weather for DateTime

    func formatWeatherForDateTime(from forecasts: [SafeFlyHour], dateTime: Date) -> String? {
        // Find the closest forecast hour to the selected datetime
        guard !forecasts.isEmpty else { return nil }

        let closestForecast = forecasts.min { forecast1, forecast2 in
            abs(forecast1.time.timeIntervalSince(dateTime)) < abs(forecast2.time.timeIntervalSince(dateTime))
        }

        guard let forecast = closestForecast else { return nil }

        // Check if the forecast is within 48 hours of selected time
        let hoursDifference = abs(forecast.time.timeIntervalSince(dateTime)) / 3600
        if hoursDifference > 48 {
            return nil // Selected time is beyond forecast range
        }

        return formatWeatherConditions(forecast)
    }

    private func formatWeatherConditions(_ hour: SafeFlyHour) -> String {
        var conditions: [String] = []

        // Temperature
        conditions.append("Temperature: \(Int(hour.forecast.temperature))F")

        // Wind
        var windStr = "Wind: \(Int(hour.forecast.windSpeed)) mph \(hour.forecast.windDirection)"
        if let gust = hour.forecast.windGust {
            windStr += ", Gusts: \(Int(gust)) mph"
        }
        conditions.append(windStr)

        // Visibility
        if let visibility = hour.visibility ?? hour.forecast.visibility {
            conditions.append("Visibility: \(String(format: "%.1f", visibility)) mi")
        }

        // Precipitation
        conditions.append("Precipitation: \(hour.forecast.precipitation)%")

        // Cloud cover
        if let cloudCover = hour.forecast.cloudCover {
            conditions.append("Cloud Cover: \(cloudCover)%")
        }

        // Conditions description
        conditions.append("Conditions: \(hour.forecast.shortForecast)")

        // Safety status
        conditions.append("Flight Safety: \(hour.safetyStatus.rawValue)")

        return conditions.joined(separator: "\n")
    }

    // MARK: - Generate PDF

    func generatePDF(from data: FlightPlanFormData) -> Data? {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            var currentPage = 1
            var yOffset: CGFloat = 50

            // Start first page
            context.beginPage()

            // Helper function to check and add new page if needed
            func checkPageBreak(requiredHeight: CGFloat) {
                if yOffset + requiredHeight > pageRect.height - 50 {
                    context.beginPage()
                    currentPage += 1
                    yOffset = 50
                }
            }

            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            "FLIGHT PLAN & SITE SURVEY".draw(at: CGPoint(x: 50, y: yOffset), withAttributes: titleAttributes)
            yOffset += 40

            // Generation date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
            let dateFont = UIFont.systemFont(ofSize: 10)
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.gray
            ]
            "Generated: \(dateFormatter.string(from: data.generatedAt))".draw(at: CGPoint(x: 50, y: yOffset), withAttributes: dateAttributes)
            yOffset += 30

            // Draw separator line
            yOffset = drawSeparatorLine(at: yOffset, pageRect: pageRect, context: context.cgContext)

            // Flight Plan Section
            yOffset = drawSectionHeader("FLIGHT INFORMATION", at: yOffset, pageRect: pageRect)

            yOffset = drawField("Pilot Name:", data.pilotName, at: yOffset, pageRect: pageRect)
            yOffset = drawField("Callsign:", data.callSign, at: yOffset, pageRect: pageRect)

            let droneInfo = [data.droneManufacturer, data.droneModel].compactMap { $0 }.joined(separator: " ")
            yOffset = drawField("Drone:", droneInfo.isEmpty ? "N/A" : droneInfo, at: yOffset, pageRect: pageRect)

            if let serial = data.droneSerialNumber, !serial.isEmpty {
                yOffset = drawField("Serial Number:", serial, at: yOffset, pageRect: pageRect)
            }
            if let regNum = data.droneRegistrationNumber, !regNum.isEmpty {
                yOffset = drawField("Registration #:", regNum, at: yOffset, pageRect: pageRect)
            }

            let takeoffFormatter = DateFormatter()
            takeoffFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
            yOffset = drawField("Takeoff Date/Time:", takeoffFormatter.string(from: data.takeoffDateTime), at: yOffset, pageRect: pageRect)

            yOffset = drawField("Location:", data.location, at: yOffset, pageRect: pageRect)
            if let coords = data.locationCoordinates, !coords.isEmpty {
                yOffset = drawField("Coordinates:", coords, at: yOffset, pageRect: pageRect)
            }

            yOffset += 15
            checkPageBreak(requiredHeight: 100)
            yOffset = drawSeparatorLine(at: yOffset, pageRect: pageRect, context: context.cgContext)

            // Site Survey Section
            yOffset = drawSectionHeader("SITE SURVEY", at: yOffset, pageRect: pageRect)

            checkPageBreak(requiredHeight: 80)
            yOffset = drawMultilineField("1. Operation Boundaries:", data.operationBoundaries, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)

            checkPageBreak(requiredHeight: 80)
            yOffset = drawMultilineField("2. Airspace and Requirements:", data.airspaceAndRequirements, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)

            checkPageBreak(requiredHeight: 80)
            yOffset = drawMultilineField("3. Altitudes and Routes:", data.altitudesAndRoutes, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)

            checkPageBreak(requiredHeight: 80)
            yOffset = drawMultilineField("4. Proximity of Manned Aircraft Operations:", data.proximityMannedAircraft, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)

            checkPageBreak(requiredHeight: 80)
            yOffset = drawMultilineField("5. Proximity of Aerodromes and Helicopters:", data.proximityAerodromes, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)

            checkPageBreak(requiredHeight: 80)
            yOffset = drawMultilineField("6. Obstacle Locations and Heights:", data.obstacleLocationsHeights, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)

            checkPageBreak(requiredHeight: 120)
            yOffset = drawMultilineField("7. Weather Conditions:", data.weatherConditions, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)

            checkPageBreak(requiredHeight: 80)
            yOffset = drawMultilineField("8. Horizontal Distance and Bystanders:", data.horizontalDistanceBystanders, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)

            if let notes = data.notes, !notes.isEmpty {
                checkPageBreak(requiredHeight: 80)
                yOffset = drawMultilineField("9. Notes:", notes, at: yOffset, pageRect: pageRect, context: context, checkPageBreak: checkPageBreak)
            }

            // Footer
            checkPageBreak(requiredHeight: 60)
            yOffset += 20
            yOffset = drawSeparatorLine(at: yOffset, pageRect: pageRect, context: context.cgContext)

            let footerFont = UIFont.italicSystemFont(ofSize: 9)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.gray
            ]
            "This flight plan was generated using Buzz. Pilots are responsible for compliance with all applicable regulations.".draw(
                in: CGRect(x: 50, y: yOffset, width: pageRect.width - 100, height: 40),
                withAttributes: footerAttributes
            )
        }

        return pdfData
    }

    // MARK: - PDF Drawing Helpers

    private func drawSectionHeader(_ title: String, at yOffset: CGFloat, pageRect: CGRect) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: 50, y: yOffset), withAttributes: attributes)
        return yOffset + 25
    }

    private func drawField(_ label: String, _ value: String, at yOffset: CGFloat, pageRect: CGRect) -> CGFloat {
        let labelFont = UIFont.boldSystemFont(ofSize: 11)
        let valueFont = UIFont.systemFont(ofSize: 11)

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]

        label.draw(at: CGPoint(x: 50, y: yOffset), withAttributes: labelAttributes)
        let labelWidth = (label as NSString).size(withAttributes: labelAttributes).width
        value.draw(at: CGPoint(x: 50 + labelWidth + 10, y: yOffset), withAttributes: valueAttributes)

        return yOffset + 20
    }

    private func drawMultilineField(_ label: String, _ value: String, at yOffset: CGFloat, pageRect: CGRect, context: UIGraphicsPDFRendererContext, checkPageBreak: (CGFloat) -> Void) -> CGFloat {
        var currentY = yOffset

        let labelFont = UIFont.boldSystemFont(ofSize: 11)
        let valueFont = UIFont.systemFont(ofSize: 11)

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]

        // Draw label
        label.draw(at: CGPoint(x: 50, y: currentY), withAttributes: labelAttributes)
        currentY += 18

        // Draw value with word wrap
        let textRect = CGRect(x: 60, y: currentY, width: pageRect.width - 110, height: CGFloat.greatestFiniteMagnitude)
        let boundingRect = (value as NSString).boundingRect(
            with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: valueAttributes,
            context: nil
        )

        value.draw(in: CGRect(x: 60, y: currentY, width: textRect.width, height: boundingRect.height), withAttributes: valueAttributes)
        currentY += boundingRect.height + 15

        return currentY
    }

    private func drawSeparatorLine(at yOffset: CGFloat, pageRect: CGRect, context: CGContext) -> CGFloat {
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: 50, y: yOffset))
        context.addLine(to: CGPoint(x: pageRect.width - 50, y: yOffset))
        context.strokePath()
        return yOffset + 15
    }

    // MARK: - Reverse Geocode Location

    func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var parts: [String] = []

                if let name = placemark.name {
                    parts.append(name)
                }
                if let city = placemark.locality {
                    parts.append(city)
                }
                if let state = placemark.administrativeArea {
                    parts.append(state)
                }
                if let country = placemark.country {
                    parts.append(country)
                }

                return parts.joined(separator: ", ")
            }
        } catch {
            print("Reverse geocoding failed: \(error.localizedDescription)")
        }

        return nil
    }
}
