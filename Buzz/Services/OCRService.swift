//
//  OCRService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Vision
import UIKit
import PDFKit

@MainActor
class OCRService {
    
    // MARK: - Extract Text from Image or PDF
    
    func extractText(from data: Data, fileType: RegistrationFileType) async throws -> String {
        if fileType == .pdf {
            return try await extractTextFromPDF(data: data)
        } else {
            return try await extractTextFromImage(data: data)
        }
    }
    
    // MARK: - Extract Text from Image
    
    private func extractTextFromImage(data: Data) async throws -> String {
        guard let image = UIImage(data: data) else {
            throw NSError(
                domain: "OCRService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]
            )
        }
        
        guard let cgImage = image.cgImage else {
            throw NSError(
                domain: "OCRService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from UIImage"]
            )
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }
            
            // Use accurate recognition for better results
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Extract Text from PDF
    
    private func extractTextFromPDF(data: Data) async throws -> String {
        guard let pdfDocument = PDFDocument(data: data) else {
            throw NSError(
                domain: "OCRService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF document from data"]
            )
        }
        
        var fullText = ""
        
        // Extract text from all pages
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // Try to extract text directly from PDF (if it's text-based)
            if let pageText = page.string {
                fullText += pageText + "\n"
            } else {
                // If PDF is image-based, convert page to image and use OCR
                let pageRect = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                let pageImage = renderer.image { context in
                    context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                    context.cgContext.scaleBy(x: 1.0, y: -1.0)
                    page.draw(with: .mediaBox, to: context.cgContext)
                }
                
                if let cgImage = pageImage.cgImage {
                    let pageText = try await extractTextFromImage(cgImage: cgImage)
                    fullText += pageText + "\n"
                }
            }
        }
        
        return fullText
    }
    
    private func extractTextFromImage(cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Parse Drone Registration Information
    
    func parseDroneRegistrationInfo(from text: String) -> DroneRegistrationInfo {
        var info = DroneRegistrationInfo()
        
        print("🔍 OCR DEBUG: Starting to parse drone registration info")
        print("🔍 OCR DEBUG: Extracted text length: \(text.count) characters")
        print("🔍 OCR DEBUG: First 500 characters of extracted text:")
        print(String(text.prefix(500)))
        print("🔍 OCR DEBUG: ========================================")
        
        // Registered Owner
        if let owner = extractField(from: text, patterns: [
            "REGISTERED OWNER[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "OWNER[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "REGISTRANT[\\s:]+([A-Za-z0-9\\s,.-]+)"
        ]) {
            info.registeredOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OCR DEBUG: Registered Owner found: '\(info.registeredOwner ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Registered Owner NOT found")
        }
        
        // UAS Manufacturer
        if let manufacturer = extractField(from: text, patterns: [
            "MANUFACTURER[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "UAS MANUFACTURER[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "MAKE[\\s:]+([A-Za-z0-9\\s,.-]+)"
        ]) {
            info.manufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OCR DEBUG: Manufacturer found: '\(info.manufacturer ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Manufacturer NOT found")
        }
        
        // UAS Model
        if let model = extractField(from: text, patterns: [
            "MODEL[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "UAS MODEL[\\s:]+([A-Za-z0-9\\s,.-]+)"
        ]) {
            info.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OCR DEBUG: Model found: '\(info.model ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Model NOT found")
        }
        
        // Serial Number
        if let serialNumber = extractField(from: text, patterns: [
            "SERIAL NUMBER[\\s:]+([A-Za-z0-9\\s-]+)",
            "SERIAL[\\s:]+([A-Za-z0-9\\s-]+)",
            "S/N[\\s:]+([A-Za-z0-9\\s-]+)"
        ]) {
            info.serialNumber = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OCR DEBUG: Serial Number found: '\(info.serialNumber ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Serial Number NOT found")
        }
        
        // Registration Number
        if let registrationNumber = extractField(from: text, patterns: [
            "REGISTRATION NUMBER[\\s:]+([A-Z0-9-]+)",
            "REGISTRATION[\\s:]+([A-Z0-9-]+)",
            "N-NUMBER[\\s:]+([A-Z0-9-]+)",
            "N[\\s:]+([A-Z0-9-]+)"
        ]) {
            info.registrationNumber = registrationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OCR DEBUG: Registration Number found: '\(info.registrationNumber ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Registration Number NOT found")
        }
        
        // Extract both dates - handle case where "ISSUED" and "EXPIRES" appear together
        print("🔍 OCR DEBUG: Searching for ISSUED and EXPIRES dates...")
        
        // First, try to find both dates when they appear together (common in forms)
        if let (issuedDate, expiresDate) = extractBothDatesTogether(from: text) {
            info.issued = issuedDate
            info.expires = expiresDate
            print("✅ OCR DEBUG: Found both dates together - Issued: '\(issuedDate)', Expires: '\(expiresDate)'")
        } else {
            // Fallback: try to extract them separately
            print("🔍 OCR DEBUG: Dates not found together, trying separate extraction...")
            
            // Extract Issued date - look for "Issued:" followed by a date
            if let issued = extractDateWithContext(from: text, keyword: "ISSUED", excludeKeywords: []) {
                info.issued = issued
                print("✅ OCR DEBUG: Issued date found: '\(info.issued ?? "nil")'")
            } else {
                print("❌ OCR DEBUG: Issued date NOT found")
            }
            
            // Extract Expires date - look for "Expires:" followed by a date
            if let expires = extractDateWithContext(from: text, keyword: "EXPIR", excludeKeywords: []) {
                info.expires = expires
                print("✅ OCR DEBUG: Expires date found: '\(info.expires ?? "nil")'")
            } else {
                print("❌ OCR DEBUG: Expires date NOT found")
            }
        }
        
        print("🔍 OCR DEBUG: ========================================")
        print("🔍 OCR DEBUG: Final parsed info:")
        print("   - Registered Owner: \(info.registeredOwner ?? "nil")")
        print("   - Manufacturer: \(info.manufacturer ?? "nil")")
        print("   - Model: \(info.model ?? "nil")")
        print("   - Serial Number: \(info.serialNumber ?? "nil")")
        print("   - Registration Number: \(info.registrationNumber ?? "nil")")
        print("   - Issued: \(info.issued ?? "nil")")
        print("   - Expires: \(info.expires ?? "nil")")
        print("🔍 OCR DEBUG: ========================================")
        
        return info
    }
    
    // MARK: - Helper Methods
    
    private func extractField(from text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) {
                let nsString = text as NSString
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first, match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    if range.location != NSNotFound {
                        var extracted = nsString.substring(with: range)
                        // Remove common suffixes that might be on the same line
                        if let newlineIndex = extracted.firstIndex(of: "\n") {
                            extracted = String(extracted[..<newlineIndex])
                        }
                        return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        return nil
    }
    
    private func extractDate(from text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let nsString = text as NSString
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                
                // Try to find the best match (first one that looks like a valid date)
                for match in results {
                    if match.numberOfRanges > 1 {
                        let range = match.range(at: 1)
                        if range.location != NSNotFound {
                            var extracted = nsString.substring(with: range)
                            // Clean up the extracted date
                            extracted = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                            // Remove any trailing text that might have been captured
                            if let newlineIndex = extracted.firstIndex(of: "\n") {
                                extracted = String(extracted[..<newlineIndex])
                            }
                            // Validate it looks like a date (contains / or -)
                            if extracted.contains("/") || extracted.contains("-") {
                                return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func extractBothDatesTogether(from text: String) -> (issued: String, expires: String)? {
        // Look for pattern like "ISSUED: EXPIRES:" or "ISSUED: ... EXPIRES:" followed by two dates
        let pattern = "(?i)(?:ISSUED[\\s:]+|ISSUE[\\s]+DATE[\\s:]+).*?(?:EXPIRES[\\s:]+|EXPIRATION[\\s:]+|EXPIRY[\\s:]+).*?([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}).*?([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let nsString = text as NSString
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first, match.numberOfRanges >= 3 {
                let firstDateRange = match.range(at: 1)
                let secondDateRange = match.range(at: 2)
                
                if firstDateRange.location != NSNotFound && secondDateRange.location != NSNotFound {
                    let firstDate = nsString.substring(with: firstDateRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    let secondDate = nsString.substring(with: secondDateRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if firstDate.contains("/") || firstDate.contains("-"),
                       secondDate.contains("/") || secondDate.contains("-") {
                        print("   ✅ Found both dates together - First: '\(firstDate)', Second: '\(secondDate)'")
                        return (firstDate, secondDate)
                    }
                }
            }
        }
        
        // Alternative: Look for "ISSUED:" and "EXPIRES:" on same line or adjacent lines, then find dates
        let uppercaseText = text.uppercased()
        let uppercaseNsString = uppercaseText as NSString
        
        // Find "ISSUED" and "EXPIRES" positions
        let issuedRange = uppercaseNsString.range(of: "ISSUED", options: [])
        let expiresRange = uppercaseNsString.range(of: "EXPIRES", options: [])
        
        if issuedRange.location != NSNotFound && expiresRange.location != NSNotFound && issuedRange.location < expiresRange.location {
            // Check if they're close together (within 50 characters)
            let distance = expiresRange.location - (issuedRange.location + issuedRange.length)
            if distance < 50 {
                // Look for dates after "EXPIRES"
                let afterExpiresStart = expiresRange.location + expiresRange.length
                let afterExpiresLength = min(50, uppercaseNsString.length - afterExpiresStart)
                if afterExpiresLength > 0 {
                    let afterExpiresRange = NSRange(location: afterExpiresStart, length: afterExpiresLength)
                    let afterExpires = uppercaseNsString.substring(with: afterExpiresRange)
                    
                    print("   🔍 Text after EXPIRES: '\(afterExpires)'")
                    
                    // Find two dates in the text after "EXPIRES"
                    let datePattern = "([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
                    if let regex = try? NSRegularExpression(pattern: datePattern, options: []) {
                        let results = regex.matches(in: afterExpires, options: [], range: NSRange(location: 0, length: afterExpires.count))
                        
                        print("   🔍 Found \(results.count) date(s) after EXPIRES")
                        
                        if results.count >= 2 {
                            let firstDateRange = results[0].range(at: 1)
                            let secondDateRange = results[1].range(at: 1)
                            
                            if firstDateRange.location != NSNotFound && secondDateRange.location != NSNotFound {
                                let firstDate = (afterExpires as NSString).substring(with: firstDateRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                let secondDate = (afterExpires as NSString).substring(with: secondDateRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                print("   ✅ Found both dates near EXPIRES - First: '\(firstDate)', Second: '\(secondDate)'")
                                return (firstDate, secondDate)
                            }
                        } else if results.count == 1 {
                            // Only one date found after EXPIRES - the first date might be between ISSUED and EXPIRES
                            // Try looking between "ISSUED" and "EXPIRES" for the first date
                            let betweenStart = issuedRange.location + issuedRange.length
                            let betweenLength = expiresRange.location - betweenStart
                            if betweenLength > 0 {
                                let betweenRange = NSRange(location: betweenStart, length: betweenLength)
                                let betweenText = uppercaseNsString.substring(with: betweenRange)
                                
                                print("   🔍 Text between ISSUED and EXPIRES: '\(betweenText)'")
                                
                                // Look for dates in the text between "ISSUED" and "EXPIRES"
                                if let betweenRegex = try? NSRegularExpression(pattern: datePattern, options: []) {
                                    let betweenResults = betweenRegex.matches(in: betweenText, options: [], range: NSRange(location: 0, length: betweenText.count))
                                    
                                    if betweenResults.count >= 1 {
                                        let firstDateRange = betweenResults[0].range(at: 1)
                                        let firstDate = (betweenText as NSString).substring(with: firstDateRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                        
                                        // Get the second date from after EXPIRES
                                        let secondDateRange = results[0].range(at: 1)
                                        let secondDate = (afterExpires as NSString).substring(with: secondDateRange).trimmingCharacters(in: .whitespacesAndNewlines)
                                        
                                        print("   ✅ Found dates - Issued: '\(firstDate)', Expires: '\(secondDate)'")
                                        return (firstDate, secondDate)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractDateWithContext(from text: String, keyword: String, excludeKeywords: [String]) -> String? {
        let uppercaseText = text.uppercased()
        let keywordUpper = keyword.uppercased()
        let nsString = text as NSString
        let uppercaseNsString = uppercaseText as NSString
        
        print("   🔍 Searching for keyword: '\(keywordUpper)'")
        print("   🔍 Excluding keywords: \(excludeKeywords)")
        
        // Find all occurrences of the keyword in the text
        var searchRange = NSRange(location: 0, length: uppercaseNsString.length)
        var foundRanges: [NSRange] = []
        
        while searchRange.location < uppercaseNsString.length {
            let foundRange = uppercaseNsString.range(of: keywordUpper, options: [], range: searchRange)
            if foundRange.location != NSNotFound {
                foundRanges.append(foundRange)
                searchRange = NSRange(location: foundRange.location + foundRange.length, length: uppercaseNsString.length - (foundRange.location + foundRange.length))
            } else {
                break
            }
        }
        
        print("   🔍 Found \(foundRanges.count) occurrence(s) of '\(keywordUpper)'")
        
        // For each occurrence, check if it's a valid match and extract the date
        for (index, keywordRange) in foundRanges.enumerated() {
            print("   🔍 Checking occurrence \(index + 1) at position \(keywordRange.location)")
            
            // Get context around the keyword (20 chars before, 50 chars after)
            let contextStart = max(0, keywordRange.location - 20)
            let contextLength = min(70, uppercaseNsString.length - contextStart)
            let contextRange = NSRange(location: contextStart, length: contextLength)
            
            if contextRange.location + contextRange.length <= uppercaseNsString.length {
                let context = uppercaseNsString.substring(with: contextRange)
                print("   🔍 Context: '\(context)'")
                
                // Check if any excluded keywords are in the context
                var shouldExclude = false
                for excludeKeyword in excludeKeywords {
                    if context.contains(excludeKeyword.uppercased()) {
                        print("   ❌ Excluding match because context contains '\(excludeKeyword.uppercased())'")
                        shouldExclude = true
                        break
                    }
                }
                
                if !shouldExclude {
                    // Look for date pattern after the keyword
                    let afterKeywordStart = keywordRange.location + keywordRange.length
                    let afterKeywordLength = min(30, nsString.length - afterKeywordStart)
                    if afterKeywordLength > 0 {
                        let afterKeywordRange = NSRange(location: afterKeywordStart, length: afterKeywordLength)
                        let afterKeyword = nsString.substring(with: afterKeywordRange)
                        print("   🔍 Text after keyword: '\(afterKeyword)'")
                        
                        // Match date pattern: MM/DD/YYYY or MM-DD-YYYY
                        let datePattern = "([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
                        if let regex = try? NSRegularExpression(pattern: datePattern, options: []) {
                            let results = regex.matches(in: afterKeyword, options: [], range: NSRange(location: 0, length: afterKeyword.count))
                            
                            print("   🔍 Found \(results.count) date pattern match(es)")
                            
                            if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
                                let dateRange = firstMatch.range(at: 1)
                                if dateRange.location != NSNotFound {
                                    let extracted = (afterKeyword as NSString).substring(with: dateRange)
                                    print("   ✅ Extracted date: '\(extracted)'")
                                    if extracted.contains("/") || extracted.contains("-") {
                                        let cleaned = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                                        print("   ✅ Returning cleaned date: '\(cleaned)'")
                                        return cleaned
                                    }
                                }
                            }
                        } else {
                            print("   ❌ Failed to create regex for date pattern")
                        }
                    } else {
                        print("   ❌ No text after keyword (length: \(afterKeywordLength))")
                    }
                }
            }
        }
        
        print("   ❌ No valid date found for keyword '\(keywordUpper)'")
        return nil
    }
    
    // MARK: - Extract Completion Date (supports written and numeric formats)
    
    private func extractCompletionDate(from text: String) -> String? {
        let uppercaseText = text.uppercased()
        let nsString = text as NSString
        let uppercaseNsString = uppercaseText as NSString
        
        // First, try to find "Course Completion Date:" or "Completion Date:"
        let keywords = ["COURSE COMPLETION DATE", "COMPLETION DATE", "DATE"]
        
        for keyword in keywords {
            let keywordUpper = keyword.uppercased()
            let keywordRange = uppercaseNsString.range(of: keywordUpper, options: [])
            
            if keywordRange.location != NSNotFound {
                // Look for date after the keyword
                let afterKeywordStart = keywordRange.location + keywordRange.length
                let afterKeywordLength = min(50, nsString.length - afterKeywordStart)
                if afterKeywordLength > 0 {
                    let afterKeywordRange = NSRange(location: afterKeywordStart, length: afterKeywordLength)
                    let afterKeyword = nsString.substring(with: afterKeywordRange)
                    
                    print("   🔍 Text after '\(keyword)': '\(afterKeyword)'")
                    
                    // Try written date format first (e.g., "November 2, 2024")
                    let writtenDatePattern = "([A-Z][a-z]+\\s+[0-9]{1,2},?\\s+[0-9]{4})"
                    if let regex = try? NSRegularExpression(pattern: writtenDatePattern, options: []) {
                        let results = regex.matches(in: afterKeyword, options: [], range: NSRange(location: 0, length: afterKeyword.count))
                        
                        if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
                            let dateRange = firstMatch.range(at: 1)
                            if dateRange.location != NSNotFound {
                                let extracted = (afterKeyword as NSString).substring(with: dateRange)
                                print("   ✅ Found written date: '\(extracted)'")
                                return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                    
                    // Fallback: Try numeric date format (e.g., "11/2/2024" or "11-2-2024")
                    let numericDatePattern = "([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})"
                    if let regex = try? NSRegularExpression(pattern: numericDatePattern, options: []) {
                        let results = regex.matches(in: afterKeyword, options: [], range: NSRange(location: 0, length: afterKeyword.count))
                        
                        if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
                            let dateRange = firstMatch.range(at: 1)
                            if dateRange.location != NSNotFound {
                                let extracted = (afterKeyword as NSString).substring(with: dateRange)
                                print("   ✅ Found numeric date: '\(extracted)'")
                                return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Extract Certificate Number (captures full number with dashes)
    
    private func extractCertificateNumber(from text: String) -> String? {
        let uppercaseText = text.uppercased()
        let nsString = text as NSString
        let uppercaseNsString = uppercaseText as NSString
        
        print("   🔍 Searching for certificate number...")
        
        // Look for "Certificate Number" (most specific)
        let keywords = [
            "COURSE COMPLETION CERTIFICATE NUMBER",
            "CERTIFICATE NUMBER"
        ]
        
        for keyword in keywords {
            let keywordRange = uppercaseNsString.range(of: keyword, options: [])
            
            if keywordRange.location != NSNotFound {
                // Look for certificate number after the keyword
                let afterKeywordStart = keywordRange.location + keywordRange.length
                let afterKeywordLength = min(40, nsString.length - afterKeywordStart)
                if afterKeywordLength > 0 {
                    let afterKeywordRange = NSRange(location: afterKeywordStart, length: afterKeywordLength)
                    let afterKeyword = nsString.substring(with: afterKeywordRange)
                    
                    print("   🔍 Text after '\(keyword)': '\(afterKeyword)'")
                    
                    // Extract all digits and any dash-like characters
                    // The pattern should match: digits followed by dash-like char, digits, dash-like char, digits
                    // Handle Unicode dashes: regular dash (-), en-dash (–), em-dash (—), etc.
                    let dashPattern = "[\\-\\u2013\\u2014\\u2015]"  // Regular dash, en-dash, em-dash, horizontal bar
                    let pattern = "([0-9]+\(dashPattern)[0-9]+\(dashPattern)[0-9]+)"
                    
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let results = regex.matches(in: afterKeyword, options: [], range: NSRange(location: 0, length: afterKeyword.count))
                        
                        if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
                            let numberRange = firstMatch.range(at: 1)
                            if numberRange.location != NSNotFound {
                                var extracted = (afterKeyword as NSString).substring(with: numberRange)
                                extracted = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // Remove any trailing text
                                if let newlineIndex = extracted.firstIndex(of: "\n") {
                                    extracted = String(extracted[..<newlineIndex])
                                }
                                
                                // Normalize all dash types to regular dash
                                extracted = extracted.replacingOccurrences(of: "\u{2013}", with: "-")  // en-dash
                                extracted = extracted.replacingOccurrences(of: "\u{2014}", with: "-")  // em-dash
                                extracted = extracted.replacingOccurrences(of: "\u{2015}", with: "-")  // horizontal bar
                                extracted = extracted.replacingOccurrences(of: " ", with: "")
                                
                                print("   ✅ Found certificate number: '\(extracted)'")
                                return extracted
                            }
                        }
                    }
                    
                    // Fallback: Extract all digits and reconstruct with dashes
                    // Look for pattern: 7 digits, separator, 8 digits, separator, 5 digits
                    let allDigitsPattern = "([0-9]{7,8}[^0-9]+[0-9]{7,9}[^0-9]+[0-9]{4,6})"
                    if let regex = try? NSRegularExpression(pattern: allDigitsPattern, options: []) {
                        let results = regex.matches(in: afterKeyword, options: [], range: NSRange(location: 0, length: afterKeyword.count))
                        
                        if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
                            let numberRange = firstMatch.range(at: 1)
                            if numberRange.location != NSNotFound {
                                var extracted = (afterKeyword as NSString).substring(with: numberRange)
                                
                                // Extract just the digits
                                let digitsOnly = extracted.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                
                                // Reconstruct with dashes: typically 7-8-5 digits
                                if digitsOnly.count >= 18 {
                                    let part1 = String(digitsOnly.prefix(7))
                                    let part2 = String(digitsOnly.dropFirst(7).prefix(8))
                                    let part3 = String(digitsOnly.dropFirst(15))
                                    let reconstructed = "\(part1)-\(part2)-\(part3)"
                                    
                                    print("   ✅ Found certificate number (reconstructed): '\(reconstructed)'")
                                    return reconstructed
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Last resort: Search the entire text for the pattern
        print("   🔍 Trying to find certificate number pattern in entire text...")
        // Look for pattern with any dash character: 7-8-5 digits
        let dashPattern = "[\\-\\u2013\\u2014\\u2015]"
        let fullTextPattern = "([0-9]{7}\(dashPattern)[0-9]{8}\(dashPattern)[0-9]{5})"
        if let regex = try? NSRegularExpression(pattern: fullTextPattern, options: []) {
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
                let numberRange = firstMatch.range(at: 1)
                if numberRange.location != NSNotFound {
                    var extracted = nsString.substring(with: numberRange)
                    // Normalize dashes
                    extracted = extracted.replacingOccurrences(of: "\u{2013}", with: "-")
                    extracted = extracted.replacingOccurrences(of: "\u{2014}", with: "-")
                    extracted = extracted.replacingOccurrences(of: "\u{2015}", with: "-")
                    print("   ✅ Found certificate number (full text search): '\(extracted)'")
                    return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        print("   ❌ No certificate number found")
        return nil
    }
    
    // MARK: - Parse Pilot License Information
    
    func parsePilotLicenseInfo(from text: String) -> PilotLicenseInfo {
        var info = PilotLicenseInfo()
        
        print("🔍 OCR DEBUG: Starting to parse pilot license info")
        print("🔍 OCR DEBUG: Extracted text length: \(text.count) characters")
        print("🔍 OCR DEBUG: First 500 characters of extracted text:")
        print(String(text.prefix(500)))
        print("🔍 OCR DEBUG: ========================================")
        
        // Name - Look for "Your Name:" or "Name:"
        if let name = extractField(from: text, patterns: [
            "YOUR NAME[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "NAME[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "PILOT NAME[\\s:]+([A-Za-z0-9\\s,.-]+)"
        ]) {
            info.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OCR DEBUG: Name found: '\(info.name ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Name NOT found")
        }
        
        // Course Completed
        if let course = extractField(from: text, patterns: [
            "COURSE COMPLETED[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "COURSE[\\s:]+([A-Za-z0-9\\s,.-]+)",
            "COMPLETED[\\s:]+([A-Za-z0-9\\s,.-]+)"
        ]) {
            info.courseCompleted = course.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ OCR DEBUG: Course Completed found: '\(info.courseCompleted ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Course Completed NOT found")
        }
        
        // Completion Date - Look for "Course Completion Date:" or "Date:"
        // Support both numeric dates (MM/DD/YYYY) and written dates (November 2, 2024)
        print("🔍 OCR DEBUG: Searching for completion date...")
        if let date = extractCompletionDate(from: text) {
            info.completionDate = date
            print("✅ OCR DEBUG: Completion Date found: '\(info.completionDate ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Completion Date NOT found")
        }
        
        // Certificate Number - Look for full certificate number with dashes
        if let certNumber = extractCertificateNumber(from: text) {
            info.certificateNumber = certNumber
            print("✅ OCR DEBUG: Certificate Number found: '\(info.certificateNumber ?? "nil")'")
        } else {
            print("❌ OCR DEBUG: Certificate Number NOT found")
        }
        
        print("🔍 OCR DEBUG: ========================================")
        print("🔍 OCR DEBUG: Final parsed pilot license info:")
        print("   - Name: \(info.name ?? "nil")")
        print("   - Course Completed: \(info.courseCompleted ?? "nil")")
        print("   - Completion Date: \(info.completionDate ?? "nil")")
        print("   - Certificate Number: \(info.certificateNumber ?? "nil")")
        print("🔍 OCR DEBUG: ========================================")
        
        return info
    }
}

// MARK: - Drone Registration Info Structure

struct DroneRegistrationInfo {
    var registeredOwner: String?
    var manufacturer: String?
    var model: String?
    var serialNumber: String?
    var registrationNumber: String?
    var issued: String?
    var expires: String?
}

// MARK: - Pilot License Info Structure

struct PilotLicenseInfo {
    var name: String?
    var courseCompleted: String?
    var completionDate: String?
    var certificateNumber: String?
}

