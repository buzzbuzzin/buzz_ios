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
import MapKit

@MainActor
class FlightPlanService: ObservableObject {
    @Published var registrations: [DroneRegistration] = []
    @Published var isLoading = false
    @Published var isGeneratingPDF = false
    @Published var isUploading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client
    private let storageBucket = "flight-plans"

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

        return conditions.joined(separator: "\n")
    }

    // MARK: - Generate PDF

    func generatePDF(from data: FlightPlanFormData) -> Data? {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            var yOffset: CGFloat = 30

            // Start first page
            context.beginPage()

            // 1. Draw logo at top center (preserve aspect ratio)
            if let logoImage = UIImage(named: "Logo") {
                let maxLogoHeight: CGFloat = 50
                let aspectRatio = logoImage.size.width / logoImage.size.height
                let logoHeight = maxLogoHeight
                let logoWidth = logoHeight * aspectRatio
                let logoX = (pageRect.width - logoWidth) / 2
                let logoRect = CGRect(x: logoX, y: yOffset, width: logoWidth, height: logoHeight)
                logoImage.draw(in: logoRect)
                yOffset += logoHeight + 8
            }

            // 2. Draw title bar (directly joined to form grid)
            yOffset = drawTitleBar(at: yOffset, pageRect: pageRect, context: context.cgContext)

            // 3. Draw form grid (main tabular structure - directly after title bar)
            yOffset = drawFormGrid(at: yOffset, data: data, pageRect: pageRect, context: context.cgContext)

            // 4. Draw certification section
            yOffset = drawCertificationSection(at: yOffset, data: data, pageRect: pageRect, context: context.cgContext)

            // 5. Draw generation date and footer (after certification)
            yOffset += 8
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
            let footerFont = UIFont.italicSystemFont(ofSize: 8)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.gray
            ]
            let footerText = "Generated: \(dateFormatter.string(from: data.generatedAt)). This flight plan was generated using Buzz. Pilots are responsible for compliance with all applicable regulations."
            footerText.draw(
                in: CGRect(x: 36, y: yOffset, width: 540, height: 30),
                withAttributes: footerAttributes
            )
        }

        return pdfData
    }

    // MARK: - Upload Flight Plan to Backend

    /// Uploads the flight plan PDF to storage and saves the flight plan data to the database
    /// - Parameters:
    ///   - pdfData: The generated PDF data
    ///   - formData: The flight plan form data
    ///   - pilotId: The pilot's UUID
    ///   - bookingId: The booking's UUID
    /// - Returns: The URL of the uploaded PDF
    func uploadFlightPlan(
        pdfData: Data,
        formData: FlightPlanFormData,
        pilotId: UUID,
        bookingId: UUID
    ) async throws -> String {
        isUploading = true
        errorMessage = nil

        defer { isUploading = false }

        do {
            // Verify authentication session
            let session = try await supabase.auth.session
            guard session.user.id == pilotId else {
                throw NSError(
                    domain: "FlightPlanService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication mismatch. Please sign in again."]
                )
            }

            // Generate unique file path: {pilot_id}/{booking_id}/{timestamp}_flight_plan.pdf
            // Use lowercased UUID to match PostgreSQL auth.uid()::text format
            let timestamp = Int(Date().timeIntervalSince1970)
            let filePath = "\(pilotId.uuidString.lowercased())/\(bookingId.uuidString.lowercased())/\(timestamp)_flight_plan.pdf"

            // Upload PDF to Supabase Storage
            do {
                let _ = try await supabase.storage
                    .from(storageBucket)
                    .upload(
                        filePath,
                        data: pdfData,
                        options: FileOptions(contentType: "application/pdf")
                    )
                print("DEBUG FlightPlan: Storage upload successful to path: \(filePath)")
            } catch {
                print("DEBUG FlightPlan: Storage upload failed: \(error.localizedDescription)")
                throw NSError(
                    domain: "FlightPlanService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to upload PDF: \(error.localizedDescription)"]
                )
            }

            // Get the full storage URL for consistency with other tables
            let pdfURL = try supabase.storage
                .from(storageBucket)
                .getPublicURL(path: filePath)
            let pdfUrl = pdfURL.absoluteString
            print("DEBUG FlightPlan: PDF URL: \(pdfUrl)")

            // Prepare the flight plan record for database
            let flightPlanRecord: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "booking_id": .string(bookingId.uuidString),
                "pilot_name": .string(formData.pilotName),
                "pilot_license_number": formData.pilotLicenseNumber.map { .string($0) } ?? .null,
                "call_sign": .string(formData.callSign),
                "drone_manufacturer": formData.droneManufacturer.map { .string($0) } ?? .null,
                "drone_model": formData.droneModel.map { .string($0) } ?? .null,
                "drone_serial_number": formData.droneSerialNumber.map { .string($0) } ?? .null,
                "drone_registration_number": formData.droneRegistrationNumber.map { .string($0) } ?? .null,
                "takeoff_date_time": .string(ISO8601DateFormatter().string(from: formData.takeoffDateTime)),
                "location": .string(formData.location),
                "latitude": formData.latitude.flatMap { Double($0) }.map { .double($0) } ?? .null,
                "longitude": formData.longitude.flatMap { Double($0) }.map { .double($0) } ?? .null,
                "regulatory_authority": .string(formData.regulatoryAuthority.rawValue),
                "max_altitude_feet": .integer(formData.maxAltitudeFeet),
                "airspace_class": .string(formData.airspaceClass.rawValue),
                "laanc_grid_ceiling": formData.laancGridCeiling.map { .integer($0) } ?? .null,
                "laanc_authorization_status": .string(formData.laancAuthorizationStatus.rawValue),
                "flight_over_people": .bool(formData.flightOverPeople),
                "flight_over_people_explanation": formData.flightOverPeopleExplanation.map { .string($0) } ?? .null,
                "vlos_type": .string(formData.vlosType.rawValue),
                "part107_compliant": .bool(formData.part107Compliant),
                "part107_non_compliance_explanation": formData.part107NonComplianceExplanation.map { .string($0) } ?? .null,
                "requires_waiver": .bool(formData.requiresWaiver),
                "waiver_safety_mitigations": formData.waiverSafetyMitigations.map { .string($0) } ?? .null,
                "waiver_operational_procedures": formData.waiverOperationalProcedures.map { .string($0) } ?? .null,
                "waiver_risk_analysis": formData.waiverRiskAnalysis.map { .string($0) } ?? .null,
                "certification_regulation": .string(formData.certificationRegulation.rawValue),
                "signature_date": formData.signatureDate.map { .string(ISO8601DateFormatter().string(from: $0)) } ?? .null,
                "pdf_url": .string(pdfUrl),
                "generated_at": .string(ISO8601DateFormatter().string(from: formData.generatedAt))
            ]

            // Insert into database
            do {
                try await supabase
                    .from("flight_plans")
                    .insert(flightPlanRecord)
                    .execute()
                print("DEBUG FlightPlan: Database insert successful")
            } catch {
                print("DEBUG FlightPlan: Database insert failed: \(error.localizedDescription)")
                throw NSError(
                    domain: "FlightPlanService",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to save flight plan: \(error.localizedDescription)"]
                )
            }

            return pdfUrl

        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
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

    private func drawSeparatorLine(at yOffset: CGFloat, pageRect: CGRect, context: CGContext) -> CGFloat {
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: 50, y: yOffset))
        context.addLine(to: CGPoint(x: pageRect.width - 50, y: yOffset))
        context.strokePath()
        return yOffset + 15
    }

    // MARK: - FAA-Style PDF Drawing Helpers

    private func drawCell(
        number: Int,
        label: String,
        value: String,
        rect: CGRect,
        context: CGContext
    ) {
        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.75)
        context.stroke(rect)

        // Draw field number (top-left corner)
        let numberFont = UIFont.boldSystemFont(ofSize: 8)
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: UIColor.darkGray
        ]
        let numberText = "\(number)."
        numberText.draw(
            at: CGPoint(x: rect.minX + 4, y: rect.minY + 3),
            withAttributes: numberAttributes
        )

        // Draw field label (uppercase, small, gray)
        let labelFont = UIFont.systemFont(ofSize: 8, weight: .medium)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor(white: 0.45, alpha: 1.0)
        ]
        label.uppercased().draw(
            at: CGPoint(x: rect.minX + 18, y: rect.minY + 4),
            withAttributes: labelAttributes
        )

        // Draw field value (below label, with text wrapping)
        let valueFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: value == "N/A" ? UIColor.gray : UIColor.black,
            .paragraphStyle: paragraphStyle
        ]

        // Draw value in a rect that allows wrapping
        let valueRect = CGRect(
            x: rect.minX + 6,
            y: rect.minY + 18,
            width: rect.width - 12,
            height: rect.height - 22
        )
        value.draw(in: valueRect, withAttributes: valueAttributes)
    }

    private func drawTitleBar(
        at y: CGFloat,
        pageRect: CGRect,
        context: CGContext
    ) -> CGFloat {
        let leftMargin: CGFloat = 36
        let contentWidth: CGFloat = 540
        let barHeight: CGFloat = 28
        let barRect = CGRect(x: leftMargin, y: y, width: contentWidth, height: barHeight)

        // Fill background
        context.setFillColor(UIColor.systemGray6.cgColor)
        context.fill(barRect)

        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.0)
        context.stroke(barRect)

        // Draw title text centered
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let title = "DRONE FLIGHT PLAN"
        let titleSize = (title as NSString).size(withAttributes: titleAttributes)
        let titleX = leftMargin + (contentWidth - titleSize.width) / 2
        let titleY = y + (barHeight - titleSize.height) / 2

        title.draw(at: CGPoint(x: titleX, y: titleY), withAttributes: titleAttributes)

        return y + barHeight
    }

    private func drawFormGrid(
        at startY: CGFloat,
        data: FlightPlanFormData,
        pageRect: CGRect,
        context: CGContext
    ) -> CGFloat {
        let leftMargin: CGFloat = 36
        let contentWidth: CGFloat = 540
        var yOffset = startY  // No gap - directly joined to title bar

        // Row heights (reduced to fit on one page)
        let standardRowHeight: CGFloat = 42

        // Row 1: TYPE (REGULATION), DRONE ID, DRONE TYPE, CALLSIGN
        let row1Widths: [CGFloat] = [120, 140, 160, 120] // Total: 540 - increased TYPE, decreased CALLSIGN
        var xOffset = leftMargin

        // Cell 1: TYPE (uses certification regulation selected by pilot)
        drawCell(
            number: 1,
            label: "REGULATION",
            value: data.certificationRegulation.displayName,
            rect: CGRect(x: xOffset, y: yOffset, width: row1Widths[0], height: standardRowHeight),
            context: context
        )
        xOffset += row1Widths[0]

        // Cell 2: DRONE IDENTIFICATION
        drawCell(
            number: 2,
            label: "DRONE IDENTIFICATION",
            value: data.droneRegistrationNumber ?? "N/A",
            rect: CGRect(x: xOffset, y: yOffset, width: row1Widths[1], height: standardRowHeight),
            context: context
        )
        xOffset += row1Widths[1]

        // Cell 3: DRONE TYPE
        let droneType = [data.droneManufacturer, data.droneModel]
            .compactMap { $0 }
            .joined(separator: " ")
        drawCell(
            number: 3,
            label: "DRONE TYPE",
            value: droneType.isEmpty ? "N/A" : droneType,
            rect: CGRect(x: xOffset, y: yOffset, width: row1Widths[2], height: standardRowHeight),
            context: context
        )
        xOffset += row1Widths[2]

        // Cell 4: PILOT CALLSIGN
        drawCell(
            number: 4,
            label: "PILOT CALLSIGN",
            value: data.callSign,
            rect: CGRect(x: xOffset, y: yOffset, width: row1Widths[3], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Row 2: DEPARTURE POINT (expanded) + DEP TIME (right-aligned)
        xOffset = leftMargin
        let row2Widths: [CGFloat] = [430, 110] // Total: 540

        // Cell 5: DEPARTURE POINT (expanded to show full address)
        drawCell(
            number: 5,
            label: "DEPARTURE POINT",
            value: data.location,
            rect: CGRect(x: xOffset, y: yOffset, width: row2Widths[0], height: standardRowHeight),
            context: context
        )
        xOffset += row2Widths[0]

        // Cell 6: DEPARTURE TIME (Zulu)
        let zuluFormatter = DateFormatter()
        zuluFormatter.dateFormat = "HHmm"
        zuluFormatter.timeZone = TimeZone(identifier: "UTC")
        let zuluTime = zuluFormatter.string(from: data.takeoffDateTime) + "Z"

        drawCell(
            number: 6,
            label: "DEP TIME (ZULU)",
            value: zuluTime,
            rect: CGRect(x: xOffset, y: yOffset, width: row2Widths[1], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Row 3: PILOT NAME, LICENSE NUMBER, LATITUDE, LONGITUDE, SERIAL NUMBER
        xOffset = leftMargin
        let row3Widths: [CGFloat] = [150, 110, 80, 90, 110] // Total: 540

        // Cell 7: PILOT NAME
        drawCell(
            number: 7,
            label: "PILOT NAME",
            value: data.pilotName,
            rect: CGRect(x: xOffset, y: yOffset, width: row3Widths[0], height: standardRowHeight),
            context: context
        )
        xOffset += row3Widths[0]

        // Cell 8: LICENSE NUMBER (new box)
        drawCell(
            number: 8,
            label: "LICENSE NUMBER",
            value: data.pilotLicenseNumber ?? "N/A",
            rect: CGRect(x: xOffset, y: yOffset, width: row3Widths[1], height: standardRowHeight),
            context: context
        )
        xOffset += row3Widths[1]

        // Cell 9: LATITUDE
        drawCell(
            number: 9,
            label: "LATITUDE",
            value: data.latitude ?? "N/A",
            rect: CGRect(x: xOffset, y: yOffset, width: row3Widths[2], height: standardRowHeight),
            context: context
        )
        xOffset += row3Widths[2]

        // Cell 10: LONGITUDE
        drawCell(
            number: 10,
            label: "LONGITUDE",
            value: data.longitude ?? "N/A",
            rect: CGRect(x: xOffset, y: yOffset, width: row3Widths[3], height: standardRowHeight),
            context: context
        )
        xOffset += row3Widths[3]

        // Cell 11: SERIAL NUMBER
        drawCell(
            number: 11,
            label: "SERIAL NUMBER",
            value: data.droneSerialNumber ?? "N/A",
            rect: CGRect(x: xOffset, y: yOffset, width: row3Widths[4], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Row 4: DATE, REGULATORY AUTHORITY, MAX ALTITUDE, AIRSPACE, LAANC STATUS
        xOffset = leftMargin
        let row4Widths: [CGFloat] = [80, 115, 85, 75, 185] // Total: 540 - reduced AIRSPACE and LAANC STATUS to fit DATE

        // Cell 12: DATE (moved from row 3)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: data.takeoffDateTime)

        drawCell(
            number: 12,
            label: "DATE",
            value: dateStr,
            rect: CGRect(x: xOffset, y: yOffset, width: row4Widths[0], height: standardRowHeight),
            context: context
        )
        xOffset += row4Widths[0]

        // Cell 13: REGULATORY AUTHORITY
        drawCell(
            number: 13,
            label: "REGULATORY AUTH",
            value: data.regulatoryAuthority.rawValue,
            rect: CGRect(x: xOffset, y: yOffset, width: row4Widths[1], height: standardRowHeight),
            context: context
        )
        xOffset += row4Widths[1]

        // Cell 14: MAX ALTITUDE
        drawCell(
            number: 14,
            label: "MAX ALTITUDE",
            value: "\(data.maxAltitudeFeet) ft AGL",
            rect: CGRect(x: xOffset, y: yOffset, width: row4Widths[2], height: standardRowHeight),
            context: context
        )
        xOffset += row4Widths[2]

        // Cell 15: AIRSPACE (reduced width)
        let airspaceValue = data.airspaceClass == .unknown ? "Unknown" : "Class \(data.airspaceClass.rawValue)"
        drawCell(
            number: 15,
            label: "AIRSPACE",
            value: airspaceValue,
            rect: CGRect(x: xOffset, y: yOffset, width: row4Widths[3], height: standardRowHeight),
            context: context
        )
        xOffset += row4Widths[3]

        // Cell 16: LAANC STATUS (reduced width)
        drawCell(
            number: 16,
            label: "AUTH STATUS",
            value: data.laancAuthorizationStatus.rawValue,
            rect: CGRect(x: xOffset, y: yOffset, width: row4Widths[4], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Row 5: VLOS TYPE, FLIGHT OVER PEOPLE, CIVIL REGULATION COMPLIANCE, WAIVER REQUIRED
        xOffset = leftMargin
        let row5Widths: [CGFloat] = [130, 120, 170, 120] // Total: 540

        // Cell 17: VLOS TYPE (with checkbox options)
        drawCheckboxCell(
            number: 17,
            label: "VLOS TYPE",
            options: [("VLOS", data.vlosType == .vlos), ("BVLOS", data.vlosType == .bvlos)],
            rect: CGRect(x: xOffset, y: yOffset, width: row5Widths[0], height: standardRowHeight),
            context: context
        )
        xOffset += row5Widths[0]

        // Cell 18: FLIGHT OVER PEOPLE (with checkbox options)
        drawCheckboxCell(
            number: 18,
            label: "FLIGHT OVER PEOPLE",
            options: [("Yes", data.flightOverPeople), ("No", !data.flightOverPeople)],
            rect: CGRect(x: xOffset, y: yOffset, width: row5Widths[1], height: standardRowHeight),
            context: context
        )
        xOffset += row5Widths[1]

        // Cell 19: Civil Regulatory Compliance (with checkbox options)
        drawCheckboxCell(
            number: 19,
            label: "CIVIL REGULATORY COMPLIANCE",
            options: [("Yes", data.part107Compliant), ("No", !data.part107Compliant)],
            rect: CGRect(x: xOffset, y: yOffset, width: row5Widths[2], height: standardRowHeight),
            context: context
        )
        xOffset += row5Widths[2]

        // Cell 20: WAIVER REQUIRED (with checkbox options)
        drawCheckboxCell(
            number: 20,
            label: "WAIVER REQUIRED",
            options: [("Yes", data.requiresWaiver), ("No", !data.requiresWaiver)],
            rect: CGRect(x: xOffset, y: yOffset, width: row5Widths[3], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Fixed explanation cells (always shown, reduced height)
        let explanationHeight: CGFloat = 55

        // Cell 21: Flight Over People Explanation (always shown)
        yOffset = drawFixedTextBlock(
            number: 21,
            label: "FLIGHT OVER PEOPLE EXPLANATION",
            text: data.flightOverPeopleExplanation ?? "",
            at: yOffset,
            width: contentWidth,
            height: explanationHeight,
            leftMargin: leftMargin,
            context: context
        )

        // Cell 22: Civil Regulatory Non-Compliance Explanation (always shown)
        yOffset = drawFixedTextBlock(
            number: 22,
            label: "CIVIL REGULATORY NON-COMPLIANCE EXPLANATION",
            text: data.part107NonComplianceExplanation ?? "",
            at: yOffset,
            width: contentWidth,
            height: explanationHeight,
            leftMargin: leftMargin,
            context: context
        )

        // Waiver Documentation Cells (directly joined to main table, no title)
        yOffset = drawWaiverSection(
            at: yOffset,
            data: data,
            startingCellNumber: 23,
            leftMargin: leftMargin,
            contentWidth: contentWidth,
            context: context
        )

        return yOffset
    }

    private func drawCheckboxCell(
        number: Int,
        label: String,
        options: [(String, Bool)],
        rect: CGRect,
        context: CGContext
    ) {
        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.75)
        context.stroke(rect)

        // Draw field number (top-left corner)
        let numberFont = UIFont.boldSystemFont(ofSize: 8)
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: UIColor.darkGray
        ]
        "\(number).".draw(
            at: CGPoint(x: rect.minX + 4, y: rect.minY + 3),
            withAttributes: numberAttributes
        )

        // Draw field label (uppercase, small, gray)
        let labelFont = UIFont.systemFont(ofSize: 8, weight: .medium)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor(white: 0.45, alpha: 1.0)
        ]
        label.uppercased().draw(
            at: CGPoint(x: rect.minX + 18, y: rect.minY + 4),
            withAttributes: labelAttributes
        )

        // Draw checkbox options
        let optionFont = UIFont.systemFont(ofSize: 11)
        let optionAttributes: [NSAttributedString.Key: Any] = [
            .font: optionFont,
            .foregroundColor: UIColor.black
        ]

        var xPos = rect.minX + 8
        let yPos = rect.minY + 25

        for (optionLabel, isSelected) in options {
            // Draw checkbox (☒ or ☐)
            let checkbox = isSelected ? "☒" : "☐"
            let checkboxFont = UIFont.systemFont(ofSize: 14)
            let checkboxAttributes: [NSAttributedString.Key: Any] = [
                .font: checkboxFont,
                .foregroundColor: UIColor.black
            ]
            checkbox.draw(at: CGPoint(x: xPos, y: yPos - 2), withAttributes: checkboxAttributes)

            // Draw option label
            let labelX = xPos + 18
            optionLabel.draw(at: CGPoint(x: labelX, y: yPos), withAttributes: optionAttributes)

            // Calculate width for next option
            let labelSize = (optionLabel as NSString).size(withAttributes: optionAttributes)
            xPos = labelX + labelSize.width + 15
        }
    }

    private func drawFixedTextBlock(
        number: Int,
        label: String,
        text: String,
        at y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        leftMargin: CGFloat,
        context: CGContext
    ) -> CGFloat {
        return drawFixedTextBlock(
            numberString: "\(number)",
            label: label,
            text: text,
            at: y,
            width: width,
            height: height,
            leftMargin: leftMargin,
            context: context
        )
    }

    private func drawFixedTextBlock(
        numberString: String,
        label: String,
        text: String,
        at y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        leftMargin: CGFloat,
        context: CGContext
    ) -> CGFloat {
        let rect = CGRect(x: leftMargin, y: y, width: width, height: height)

        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.75)
        context.stroke(rect)

        // Draw field number
        let numberFont = UIFont.boldSystemFont(ofSize: 8)
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: UIColor.darkGray
        ]
        "\(numberString).".draw(at: CGPoint(x: rect.minX + 4, y: rect.minY + 3), withAttributes: numberAttributes)

        // Draw label - use larger offset for longer number strings (like "23a.")
        let labelFont = UIFont.systemFont(ofSize: 8, weight: .medium)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor(white: 0.45, alpha: 1.0)
        ]
        let labelXOffset: CGFloat = numberString.count > 2 ? 30 : 18
        label.uppercased().draw(at: CGPoint(x: rect.minX + labelXOffset, y: rect.minY + 4), withAttributes: labelAttributes)

        // Draw text content (if any)
        if !text.isEmpty {
            let textFont = UIFont.systemFont(ofSize: 11)
            let textAttributes: [NSAttributedString.Key: Any] = [.font: textFont]
            let contentRect = CGRect(x: rect.minX + 10, y: rect.minY + 20, width: width - 20, height: height - 25)
            text.draw(in: contentRect, withAttributes: textAttributes)
        }

        return y + height
    }

    private func drawTextBlock(
        number: Int,
        label: String,
        text: String,
        at y: CGFloat,
        width: CGFloat,
        leftMargin: CGFloat,
        context: CGContext
    ) -> CGFloat {
        // Calculate height based on text length
        let textFont = UIFont.systemFont(ofSize: 11)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: textFont]
        let textRect = CGRect(x: 0, y: 0, width: width - 20, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(
            with: textRect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: textAttributes,
            context: nil
        )
        let minHeight: CGFloat = 60
        let cellHeight = max(minHeight, boundingRect.height + 35)

        let rect = CGRect(x: leftMargin, y: y, width: width, height: cellHeight)

        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.75)
        context.stroke(rect)

        // Draw field number
        let numberFont = UIFont.boldSystemFont(ofSize: 8)
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: UIColor.darkGray
        ]
        "\(number).".draw(at: CGPoint(x: rect.minX + 4, y: rect.minY + 3), withAttributes: numberAttributes)

        // Draw label
        let labelFont = UIFont.systemFont(ofSize: 8, weight: .medium)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor(white: 0.45, alpha: 1.0)
        ]
        label.uppercased().draw(at: CGPoint(x: rect.minX + 18, y: rect.minY + 4), withAttributes: labelAttributes)

        // Draw text content
        let contentRect = CGRect(x: rect.minX + 10, y: rect.minY + 20, width: width - 20, height: cellHeight - 25)
        text.draw(in: contentRect, withAttributes: textAttributes)

        return y + cellHeight
    }

    private func drawWaiverSection(
        at y: CGFloat,
        data: FlightPlanFormData,
        startingCellNumber: Int,
        leftMargin: CGFloat,
        contentWidth: CGFloat,
        context: CGContext
    ) -> CGFloat {
        var yOffset = y
        let waiverFieldHeight: CGFloat = 55

        // Cell 22a: Safety Mitigations (always shown, joined directly to main table)
        yOffset = drawFixedTextBlock(
            numberString: "\(startingCellNumber)a",
            label: "WAIVER: SAFETY MITIGATIONS",
            text: data.waiverSafetyMitigations ?? "",
            at: yOffset,
            width: contentWidth,
            height: waiverFieldHeight,
            leftMargin: leftMargin,
            context: context
        )

        // Cell 22b: Operational Procedures (always shown)
        yOffset = drawFixedTextBlock(
            numberString: "\(startingCellNumber)b",
            label: "WAIVER: OPERATIONAL PROCEDURES",
            text: data.waiverOperationalProcedures ?? "",
            at: yOffset,
            width: contentWidth,
            height: waiverFieldHeight,
            leftMargin: leftMargin,
            context: context
        )

        // Cell 22c: Risk Analysis (always shown)
        yOffset = drawFixedTextBlock(
            numberString: "\(startingCellNumber)c",
            label: "WAIVER: RISK ANALYSIS",
            text: data.waiverRiskAnalysis ?? "",
            at: yOffset,
            width: contentWidth,
            height: waiverFieldHeight,
            leftMargin: leftMargin,
            context: context
        )

        return yOffset
    }

    private func drawCertificationSection(
        at y: CGFloat,
        data: FlightPlanFormData,
        pageRect: CGRect,
        context: CGContext
    ) -> CGFloat {
        let leftMargin: CGFloat = 36
        let contentWidth: CGFloat = 540
        var yOffset = y + 10

        // Section header
        let headerFont = UIFont.boldSystemFont(ofSize: 10)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        "PILOT CERTIFICATION".draw(
            at: CGPoint(x: leftMargin, y: yOffset),
            withAttributes: headerAttributes
        )
        yOffset += 14

        // Certification text with regulation
        let certFont = UIFont.systemFont(ofSize: 8)
        let certAttributes: [NSAttributedString.Key: Any] = [
            .font: certFont,
            .foregroundColor: UIColor.darkGray
        ]
        let boldCertFont = UIFont.boldSystemFont(ofSize: 8)
        let boldCertAttributes: [NSAttributedString.Key: Any] = [
            .font: boldCertFont,
            .foregroundColor: UIColor.black
        ]

        // Build attributed string with regulation highlighted
        let certText = NSMutableAttributedString()
        certText.append(NSAttributedString(
            string: "I certify that this flight will be conducted in accordance with all applicable civil regulations under ",
            attributes: certAttributes
        ))
        certText.append(NSAttributedString(
            string: data.certificationRegulation.displayName,
            attributes: boldCertAttributes
        ))
        certText.append(NSAttributedString(
            string: " and that I am the remote pilot in command responsible for this operation.",
            attributes: certAttributes
        ))

        let certRect = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 22)
        certText.draw(in: certRect)
        yOffset += 28

        // Signature and Date boxes
        let signatureBoxWidth: CGFloat = 250
        let dateBoxWidth: CGFloat = 150
        let boxHeight: CGFloat = 50
        let boxSpacing: CGFloat = 40

        // Signature Box
        let signatureRect = CGRect(x: leftMargin, y: yOffset, width: signatureBoxWidth, height: boxHeight)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.75)
        context.stroke(signatureRect)

        // Draw signature image if available
        if let signatureImage = data.signatureImage {
            let imageInset: CGFloat = 5
            let imageRect = CGRect(
                x: signatureRect.minX + imageInset,
                y: signatureRect.minY + imageInset,
                width: signatureRect.width - (imageInset * 2),
                height: signatureRect.height - (imageInset * 2)
            )
            signatureImage.draw(in: imageRect)
        }

        // Signature label
        let sigLabelFont = UIFont.systemFont(ofSize: 8)
        let sigLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: sigLabelFont,
            .foregroundColor: UIColor.gray
        ]
        "PILOT SIGNATURE".draw(
            at: CGPoint(x: leftMargin + 4, y: yOffset + boxHeight + 3),
            withAttributes: sigLabelAttributes
        )

        // Date Box
        let dateBoxX = leftMargin + signatureBoxWidth + boxSpacing
        let dateRect = CGRect(x: dateBoxX, y: yOffset, width: dateBoxWidth, height: boxHeight)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.75)
        context.stroke(dateRect)

        // Draw date if available
        if let signatureDate = data.signatureDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: signatureDate)

            let dateValueFont = UIFont.systemFont(ofSize: 16, weight: .medium)
            let dateValueAttributes: [NSAttributedString.Key: Any] = [
                .font: dateValueFont,
                .foregroundColor: UIColor.black
            ]
            let dateSize = (dateString as NSString).size(withAttributes: dateValueAttributes)
            let dateX = dateBoxX + (dateBoxWidth - dateSize.width) / 2
            let dateY = yOffset + (boxHeight - dateSize.height) / 2
            dateString.draw(at: CGPoint(x: dateX, y: dateY), withAttributes: dateValueAttributes)
        }

        // Date label
        "DATE".draw(
            at: CGPoint(x: dateBoxX + 4, y: yOffset + boxHeight + 3),
            withAttributes: sigLabelAttributes
        )

        return yOffset + boxHeight + 20
    }

    private func truncateText(_ text: String, toWidth maxWidth: CGFloat, font: UIFont) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var truncated = text
        var size = (truncated as NSString).size(withAttributes: attributes)

        if size.width <= maxWidth {
            return text
        }

        while size.width > maxWidth && truncated.count > 0 {
            truncated = String(truncated.dropLast())
            let withEllipsis = truncated + "..."
            size = (withEllipsis as NSString).size(withAttributes: attributes)
            if size.width <= maxWidth {
                return withEllipsis
            }
        }

        return truncated
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

    // MARK: - Address Search

    func searchAddresses(query: String) async -> [AddressSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            return response.mapItems.prefix(5).map { item in
                let placemark = item.placemark

                // Build title (street address)
                var titleParts: [String] = []
                if let subThoroughfare = placemark.subThoroughfare {
                    titleParts.append(subThoroughfare)
                }
                if let thoroughfare = placemark.thoroughfare {
                    titleParts.append(thoroughfare)
                }
                let title = titleParts.isEmpty ? (placemark.name ?? "Unknown") : titleParts.joined(separator: " ")

                // Build subtitle (city, state)
                var subtitleParts: [String] = []
                if let city = placemark.locality {
                    subtitleParts.append(city)
                }
                if let state = placemark.administrativeArea {
                    subtitleParts.append(state)
                }
                if let postalCode = placemark.postalCode {
                    subtitleParts.append(postalCode)
                }
                let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: ", ")

                // Build full address
                var fullParts: [String] = []
                if !title.isEmpty && title != "Unknown" {
                    fullParts.append(title)
                }
                if let city = placemark.locality {
                    fullParts.append(city)
                }
                if let state = placemark.administrativeArea {
                    fullParts.append(state)
                }
                if let postalCode = placemark.postalCode {
                    fullParts.append(postalCode)
                }
                if let country = placemark.country {
                    fullParts.append(country)
                }
                let fullAddress = fullParts.joined(separator: ", ")

                return AddressSuggestion(
                    title: title,
                    subtitle: subtitle,
                    fullAddress: fullAddress,
                    coordinate: placemark.location?.coordinate
                )
            }
        } catch {
            print("Address search failed: \(error.localizedDescription)")
            return []
        }
    }
}
