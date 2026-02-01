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

        return conditions.joined(separator: "\n")
    }

    // MARK: - Generate PDF

    func generatePDF(from data: FlightPlanFormData) -> Data? {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            var yOffset: CGFloat = 40

            // Start first page
            context.beginPage()

            // 1. Draw logo at top center (preserve aspect ratio)
            if let logoImage = UIImage(named: "Logo") {
                let maxLogoHeight: CGFloat = 70
                let aspectRatio = logoImage.size.width / logoImage.size.height
                let logoHeight = maxLogoHeight
                let logoWidth = logoHeight * aspectRatio
                let logoX = (pageRect.width - logoWidth) / 2
                let logoRect = CGRect(x: logoX, y: yOffset, width: logoWidth, height: logoHeight)
                logoImage.draw(in: logoRect)
                yOffset += logoHeight + 15
            }

            // 2. Draw title bar
            yOffset = drawTitleBar(at: yOffset, pageRect: pageRect, context: context.cgContext)

            // 3. Draw generation date (right-aligned)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
            let dateFont = UIFont.systemFont(ofSize: 9)
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.gray
            ]
            let dateText = "Generated: \(dateFormatter.string(from: data.generatedAt))"
            let dateSize = (dateText as NSString).size(withAttributes: dateAttributes)
            let dateX = pageRect.width - 36 - dateSize.width
            dateText.draw(at: CGPoint(x: dateX, y: yOffset + 5), withAttributes: dateAttributes)
            yOffset += 25

            // 4. Draw form grid (main tabular structure)
            yOffset = drawFormGrid(at: yOffset, data: data, pageRect: pageRect, context: context.cgContext)

            // 5. Draw certification section
            yOffset = drawCertificationSection(at: yOffset, data: data, pageRect: pageRect, context: context.cgContext)

            // 6. Draw footer disclaimer
            yOffset += 15
            let footerFont = UIFont.italicSystemFont(ofSize: 9)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.gray
            ]
            "This flight plan was generated using Buzz. Pilots are responsible for compliance with all applicable regulations.".draw(
                in: CGRect(x: 36, y: yOffset, width: 540, height: 40),
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

        // Draw field value (below label, prominent)
        let valueFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: value == "N/A" ? UIColor.gray : UIColor.black
        ]

        // Truncate if too long
        let maxValueWidth = rect.width - 16
        let displayValue = truncateText(value, toWidth: maxValueWidth, font: valueFont)

        let valueY = rect.minY + 20
        displayValue.draw(
            at: CGPoint(x: rect.minX + 8, y: valueY),
            withAttributes: valueAttributes
        )
    }

    private func drawTitleBar(
        at y: CGFloat,
        pageRect: CGRect,
        context: CGContext
    ) -> CGFloat {
        let leftMargin: CGFloat = 36
        let contentWidth: CGFloat = 540
        let barHeight: CGFloat = 35
        let barRect = CGRect(x: leftMargin, y: y, width: contentWidth, height: barHeight)

        // Fill background
        context.setFillColor(UIColor.systemGray6.cgColor)
        context.fill(barRect)

        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.0)
        context.stroke(barRect)

        // Draw "UAS" badge on left
        let badgeFont = UIFont.boldSystemFont(ofSize: 10)
        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: UIColor.white
        ]
        let badge = "UAS"
        let badgeSize = (badge as NSString).size(withAttributes: badgeAttributes)
        let badgePadding: CGFloat = 6
        let badgeRect = CGRect(
            x: leftMargin + 8,
            y: y + (barHeight - badgeSize.height - badgePadding) / 2,
            width: badgeSize.width + badgePadding * 2,
            height: badgeSize.height + badgePadding
        )

        context.setFillColor(UIColor.systemBlue.cgColor)
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4)
        context.addPath(badgePath.cgPath)
        context.fillPath()

        badge.draw(
            at: CGPoint(x: badgeRect.minX + badgePadding, y: badgeRect.minY + badgePadding / 2),
            withAttributes: badgeAttributes
        )

        // Draw title text centered
        let titleFont = UIFont.boldSystemFont(ofSize: 18)
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
        var yOffset = startY + 10

        // Row heights
        let standardRowHeight: CGFloat = 55
        let remarksRowHeight: CGFloat = 45

        // Row 1: TYPE, DRONE ID, DRONE TYPE, CALLSIGN
        let row1Widths: [CGFloat] = [80, 150, 160, 150] // Total: 540
        var xOffset = leftMargin

        // Cell 1: TYPE
        drawCell(
            number: 1,
            label: "TYPE",
            value: "PART 107",
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

        // Row 2: DEPARTURE POINT, DEPARTURE TIME, LATITUDE, LONGITUDE
        xOffset = leftMargin
        let row2Widths: [CGFloat] = [220, 110, 105, 105] // Total: 540

        // Cell 5: DEPARTURE POINT
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
        xOffset += row2Widths[1]

        // Cell 7: LATITUDE
        drawCell(
            number: 7,
            label: "LATITUDE",
            value: data.latitude ?? "N/A",
            rect: CGRect(x: xOffset, y: yOffset, width: row2Widths[2], height: standardRowHeight),
            context: context
        )
        xOffset += row2Widths[2]

        // Cell 8: LONGITUDE
        drawCell(
            number: 8,
            label: "LONGITUDE",
            value: data.longitude ?? "N/A",
            rect: CGRect(x: xOffset, y: yOffset, width: row2Widths[3], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Row 3: PILOT NAME, SERIAL NUMBER, DATE
        xOffset = leftMargin
        let row3Widths: [CGFloat] = [270, 135, 135]

        // Cell 9: PILOT NAME
        drawCell(
            number: 9,
            label: "PILOT NAME",
            value: data.pilotName,
            rect: CGRect(x: xOffset, y: yOffset, width: row3Widths[0], height: standardRowHeight),
            context: context
        )
        xOffset += row3Widths[0]

        // Cell 10: SERIAL NUMBER
        drawCell(
            number: 10,
            label: "SERIAL NUMBER",
            value: data.droneSerialNumber ?? "N/A",
            rect: CGRect(x: xOffset, y: yOffset, width: row3Widths[1], height: standardRowHeight),
            context: context
        )
        xOffset += row3Widths[1]

        // Cell 11: DATE
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        let dateStr = dateFormatter.string(from: data.takeoffDateTime)

        drawCell(
            number: 11,
            label: "DATE",
            value: dateStr,
            rect: CGRect(x: xOffset, y: yOffset, width: row3Widths[2], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Row 4: REMARKS (full width)
        drawCell(
            number: 12,
            label: "REMARKS",
            value: "",
            rect: CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: remarksRowHeight),
            context: context
        )

        yOffset += remarksRowHeight

        // Row 5: REGULATORY AUTHORITY, MAX ALTITUDE, AIRSPACE, LAANC STATUS
        xOffset = leftMargin
        let row5Widths: [CGFloat] = [135, 95, 95, 215] // Total: 540

        // Cell 13: REGULATORY AUTHORITY
        drawCell(
            number: 13,
            label: "REGULATORY AUTH",
            value: data.regulatoryAuthority.rawValue,
            rect: CGRect(x: xOffset, y: yOffset, width: row5Widths[0], height: standardRowHeight),
            context: context
        )
        xOffset += row5Widths[0]

        // Cell 14: MAX ALTITUDE
        drawCell(
            number: 14,
            label: "MAX ALTITUDE",
            value: "\(data.maxAltitudeFeet) ft AGL",
            rect: CGRect(x: xOffset, y: yOffset, width: row5Widths[1], height: standardRowHeight),
            context: context
        )
        xOffset += row5Widths[1]

        // Cell 15: AIRSPACE
        let airspaceValue = data.airspaceClass == .unknown ? "Unknown" : "Class \(data.airspaceClass.rawValue)"
        drawCell(
            number: 15,
            label: "AIRSPACE",
            value: airspaceValue,
            rect: CGRect(x: xOffset, y: yOffset, width: row5Widths[2], height: standardRowHeight),
            context: context
        )
        xOffset += row5Widths[2]

        // Cell 16: LAANC STATUS
        drawCell(
            number: 16,
            label: "LAANC STATUS",
            value: data.laancAuthorizationStatus.rawValue,
            rect: CGRect(x: xOffset, y: yOffset, width: row5Widths[3], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Row 6: VLOS TYPE, FLIGHT OVER PEOPLE, PART 107 COMPLIANT
        xOffset = leftMargin
        let row6Widths: [CGFloat] = [110, 150, 280] // Total: 540

        // Cell 17: VLOS TYPE
        drawCell(
            number: 17,
            label: "VLOS TYPE",
            value: data.vlosType.rawValue,
            rect: CGRect(x: xOffset, y: yOffset, width: row6Widths[0], height: standardRowHeight),
            context: context
        )
        xOffset += row6Widths[0]

        // Cell 18: FLIGHT OVER PEOPLE
        drawCell(
            number: 18,
            label: "FLIGHT OVER PEOPLE",
            value: data.flightOverPeople ? "Yes" : "No",
            rect: CGRect(x: xOffset, y: yOffset, width: row6Widths[1], height: standardRowHeight),
            context: context
        )
        xOffset += row6Widths[1]

        // Cell 19: PART 107 COMPLIANT
        drawCell(
            number: 19,
            label: "PART 107 COMPLIANT",
            value: data.part107Compliant ? "Yes" : "No",
            rect: CGRect(x: xOffset, y: yOffset, width: row6Widths[2], height: standardRowHeight),
            context: context
        )

        yOffset += standardRowHeight

        // Conditional Explanation Cells
        var cellNumber = 20

        // Cell 20: Flight Over People Explanation (if applicable)
        if data.flightOverPeople, let explanation = data.flightOverPeopleExplanation, !explanation.isEmpty {
            yOffset = drawTextBlock(
                number: cellNumber,
                label: "FLIGHT OVER PEOPLE EXPLANATION",
                text: explanation,
                at: yOffset,
                width: contentWidth,
                leftMargin: leftMargin,
                context: context
            )
            cellNumber += 1
        }

        // Cell 21: Part 107 Non-Compliance Explanation (if applicable)
        if !data.part107Compliant, let explanation = data.part107NonComplianceExplanation, !explanation.isEmpty {
            yOffset = drawTextBlock(
                number: cellNumber,
                label: "PART 107 NON-COMPLIANCE EXPLANATION",
                text: explanation,
                at: yOffset,
                width: contentWidth,
                leftMargin: leftMargin,
                context: context
            )
            cellNumber += 1
        }

        // Waiver Documentation Section (if applicable)
        if data.requiresWaiver {
            yOffset = drawWaiverSection(
                at: yOffset,
                data: data,
                startingCellNumber: cellNumber,
                leftMargin: leftMargin,
                contentWidth: contentWidth,
                context: context
            )
        }

        return yOffset
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
        var yOffset = y + 10
        var cellNumber = startingCellNumber

        // Section header
        let headerFont = UIFont.boldSystemFont(ofSize: 10)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        "WAIVER DOCUMENTATION".draw(at: CGPoint(x: leftMargin, y: yOffset), withAttributes: headerAttributes)
        yOffset += 18

        // Safety Mitigations
        if let safetyMitigations = data.waiverSafetyMitigations, !safetyMitigations.isEmpty {
            yOffset = drawTextBlock(
                number: cellNumber,
                label: "I. SAFETY MITIGATIONS",
                text: safetyMitigations,
                at: yOffset,
                width: contentWidth,
                leftMargin: leftMargin,
                context: context
            )
            cellNumber += 1
        }

        // Operational Procedures
        if let operationalProcedures = data.waiverOperationalProcedures, !operationalProcedures.isEmpty {
            yOffset = drawTextBlock(
                number: cellNumber,
                label: "II. OPERATIONAL PROCEDURES",
                text: operationalProcedures,
                at: yOffset,
                width: contentWidth,
                leftMargin: leftMargin,
                context: context
            )
            cellNumber += 1
        }

        // Risk Analysis
        if let riskAnalysis = data.waiverRiskAnalysis, !riskAnalysis.isEmpty {
            yOffset = drawTextBlock(
                number: cellNumber,
                label: "III. RISK ANALYSIS",
                text: riskAnalysis,
                at: yOffset,
                width: contentWidth,
                leftMargin: leftMargin,
                context: context
            )
        }

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
        var yOffset = y + 20

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
        yOffset += 18

        // Certification text
        let certFont = UIFont.systemFont(ofSize: 9)
        let certAttributes: [NSAttributedString.Key: Any] = [
            .font: certFont,
            .foregroundColor: UIColor.darkGray
        ]
        let certText = "I certify that this flight will be conducted in accordance with all applicable FAA regulations and that I am the remote pilot in command responsible for this operation."

        let certRect = CGRect(x: leftMargin, y: yOffset, width: contentWidth, height: 30)
        certText.draw(in: certRect, withAttributes: certAttributes)
        yOffset += 40

        // Signature and Date boxes
        let signatureBoxWidth: CGFloat = 250
        let dateBoxWidth: CGFloat = 150
        let boxHeight: CGFloat = 60
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
            dateFormatter.dateFormat = "MM/dd/yyyy"
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
