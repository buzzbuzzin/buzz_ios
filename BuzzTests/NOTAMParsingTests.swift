import Foundation
import Testing
@testable import Buzz

struct NOTAMParsingTests {

    // MARK: - NOTAM Decoding

    @Test func notamDecodesWithAllFieldsPresent() throws {
        let json = """
        {
            "id": "abc123",
            "notamNumber": "A1234/26",
            "icaoCode": "CYYZ",
            "location": "Toronto Pearson",
            "message": "RWY 05/23 CLSD",
            "rawText": "A1234/26 NOTAMN Q)CZYZ/QMRLC/IV/NBO/A/000/999 A)CYYZ",
            "startsAt": "2026-03-01T00:00:00Z",
            "endsAt": "2026-03-15T00:00:00Z",
            "issuedAt": "2026-02-28T12:00:00Z",
            "isPermanent": false,
            "isEstimated": false,
            "interpretation": {
                "category": "RUNWAY",
                "subcategory": "CLOSURE",
                "excerpt": "Runway 05/23 closed",
                "description": "Runway 05/23 closed for maintenance",
                "affectedElements": [
                    {
                        "type": "runway",
                        "identifier": "05/23",
                        "effect": "closed",
                        "details": "Closed for maintenance"
                    }
                ],
                "schedules": [
                    {
                        "description": "Daily 0600-1800 UTC",
                        "source": "NOTAM text",
                        "durationHours": 11.5666666667,
                        "isSunriseSunset": false
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let notam = try JSONDecoder().decode(NOTAM.self, from: json)

        #expect(notam.id == "abc123")
        #expect(notam.notamNumber == "A1234/26")
        #expect(notam.icaoCode == "CYYZ")
        #expect(notam.location == "Toronto Pearson")
        #expect(notam.message == "RWY 05/23 CLSD")
        #expect(notam.rawText.contains("NOTAMN"))
        #expect(notam.startsAt == "2026-03-01T00:00:00Z")
        #expect(notam.endsAt == "2026-03-15T00:00:00Z")
        #expect(notam.issuedAt == "2026-02-28T12:00:00Z")
        #expect(notam.isPermanent == false)
        #expect(notam.isEstimated == false)
        #expect(notam.interpretation.category == "RUNWAY")
        #expect(notam.interpretation.subcategory == "CLOSURE")
        #expect(notam.interpretation.excerpt == "Runway 05/23 closed")
        #expect(notam.interpretation.description == "Runway 05/23 closed for maintenance")
        #expect(notam.interpretation.affectedElements.count == 1)
        #expect(notam.interpretation.affectedElements.first?.identifier == "05/23")
        #expect(notam.interpretation.schedules.count == 1)
        #expect(notam.interpretation.schedules.first?.durationHours == 11.5666666667)
    }

    @Test func notamDecodesWithNullOptionalFields() throws {
        let json = """
        {
            "id": "def456",
            "notamNumber": "B5678/26",
            "icaoCode": "KJFK",
            "location": "John F Kennedy Intl",
            "message": null,
            "rawText": null,
            "startsAt": "2026-03-01T00:00:00Z",
            "endsAt": "2026-03-10T00:00:00Z",
            "issuedAt": "2026-02-28T12:00:00Z",
            "isPermanent": false,
            "isEstimated": false,
            "interpretation": {
                "category": "LIGHTING",
                "excerpt": "PAPI RWY 04L unserviceable",
                "description": "PAPI for runway 04L out of service"
            }
        }
        """.data(using: .utf8)!

        let notam = try JSONDecoder().decode(NOTAM.self, from: json)

        #expect(notam.id == "def456")
        #expect(notam.message == "")
        #expect(notam.rawText == "")
        #expect(notam.icaoCode == "KJFK")
    }

    @Test func notamDecodesWithMissingInterpretation() throws {
        let json = """
        {
            "id": "ghi789",
            "notamNumber": "C9012/26",
            "icaoCode": "EGLL",
            "location": "Heathrow",
            "message": "TWY A CLSD",
            "rawText": "C9012/26 NOTAMN...",
            "startsAt": "2026-03-02T00:00:00Z",
            "endsAt": "2026-03-05T00:00:00Z",
            "issuedAt": "2026-03-01T10:00:00Z",
            "isPermanent": false,
            "isEstimated": true
        }
        """.data(using: .utf8)!

        let notam = try JSONDecoder().decode(NOTAM.self, from: json)

        #expect(notam.id == "ghi789")
        #expect(notam.interpretation.category == "OTHER")
        #expect(notam.interpretation.excerpt == "")
        #expect(notam.interpretation.description == "")
        #expect(notam.interpretation.affectedElements.isEmpty)
        #expect(notam.interpretation.schedules.isEmpty)
        #expect(notam.isEstimated == true)
    }

    @Test func isPermanentDefaultsToFalseWhenMissing() throws {
        let json = """
        {
            "id": "perm001",
            "notamNumber": "D1111/26",
            "icaoCode": "LFPG",
            "location": "Paris Charles de Gaulle",
            "message": "New obstacle crane",
            "rawText": "D1111/26 NOTAMN...",
            "startsAt": "2026-03-01T00:00:00Z",
            "endsAt": "2026-04-01T00:00:00Z",
            "issuedAt": "2026-02-28T08:00:00Z",
            "isEstimated": false,
            "interpretation": {
                "category": "OBSTACLE",
                "excerpt": "Crane erected",
                "description": "Crane erected near approach path"
            }
        }
        """.data(using: .utf8)!

        let notam = try JSONDecoder().decode(NOTAM.self, from: json)

        #expect(notam.isPermanent == false)
    }

    // MARK: - NOTAMResponse Decoding

    @Test func notamResponseDecodesWithOnlyErrorField() throws {
        let json = """
        {
            "error": "Something went wrong"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(NOTAMResponse.self, from: json)

        #expect(response.error == "Something went wrong")
        #expect(response.notams.isEmpty)
        #expect(response.airports.isEmpty)
        #expect(response.totalCount == nil)
        #expect(response.message == nil)
    }

    @Test func notamResponseDecodesWithCompleteData() throws {
        let json = """
        {
            "notams": [
                {
                    "id": "notam-1",
                    "notamNumber": "A0001/26",
                    "icaoCode": "CYYZ",
                    "location": "Toronto Pearson",
                    "message": "RWY 05/23 CLSD",
                    "rawText": "A0001/26 NOTAMN...",
                    "startsAt": "2026-03-01T00:00:00Z",
                    "endsAt": "2026-03-15T00:00:00Z",
                    "issuedAt": "2026-02-28T12:00:00Z",
                    "isPermanent": false,
                    "isEstimated": false,
                    "interpretation": {
                        "category": "RUNWAY",
                        "subcategory": "CLOSURE",
                        "excerpt": "Runway 05/23 closed",
                        "description": "Runway 05/23 closed for maintenance"
                    }
                },
                {
                    "id": "notam-2",
                    "notamNumber": "A0002/26",
                    "icaoCode": "CYYZ",
                    "location": "Toronto Pearson",
                    "message": "PAPI RWY 24L U/S",
                    "rawText": "A0002/26 NOTAMN...",
                    "startsAt": "2026-03-02T00:00:00Z",
                    "endsAt": "2026-03-10T00:00:00Z",
                    "issuedAt": "2026-03-01T08:00:00Z",
                    "isPermanent": false,
                    "isEstimated": false,
                    "interpretation": {
                        "category": "LIGHTING",
                        "excerpt": "PAPI unserviceable",
                        "description": "PAPI for runway 24L out of service"
                    }
                }
            ],
            "airports": ["CYYZ"],
            "totalCount": 2,
            "message": "NOTAMs fetched successfully"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(NOTAMResponse.self, from: json)

        #expect(response.notams.count == 2)
        #expect(response.airports == ["CYYZ"])
        #expect(response.totalCount == 2)
        #expect(response.message == "NOTAMs fetched successfully")
        #expect(response.error == nil)
        #expect(response.notams[0].id == "notam-1")
        #expect(response.notams[1].interpretation.category == "LIGHTING")
    }

    // MARK: - NOTAMInterpretation Decoding

    @Test func interpretationDecodesWithMissingAffectedElementsAndSchedules() throws {
        let json = """
        {
            "category": "AIRSPACE",
            "subcategory": "RESTRICTION",
            "excerpt": "Temporary restricted area",
            "description": "Temporary restricted area for military exercise"
        }
        """.data(using: .utf8)!

        let interpretation = try JSONDecoder().decode(NOTAMInterpretation.self, from: json)

        #expect(interpretation.category == "AIRSPACE")
        #expect(interpretation.subcategory == "RESTRICTION")
        #expect(interpretation.excerpt == "Temporary restricted area")
        #expect(interpretation.affectedElements.isEmpty)
        #expect(interpretation.schedules.isEmpty)
    }
}
