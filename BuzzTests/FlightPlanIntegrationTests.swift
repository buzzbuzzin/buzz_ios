//
//  FlightPlanIntegrationTests.swift
//  BuzzTests
//
//  Integration tests that exercise the full flight plan lifecycle against
//  production Supabase: create a test booking, upload a PDF to storage,
//  insert a flight_plan record, verify the round-trip, and clean up.
//

import XCTest
import Supabase
@testable import Buzz

@MainActor
final class FlightPlanIntegrationTests: IntegrationTestCase {

    private var flightPlanService: FlightPlanService!

    /// Lowercase user ID for storage paths (matches auth.uid()::text).
    private var userFolder: String {
        TestUser.id.uuidString.lowercased()
    }

    override func setUp() async throws {
        try await super.setUp()
        flightPlanService = FlightPlanService()
    }

    override func tearDown() async throws {
        flightPlanService = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a minimal valid PDF for testing.
    private func makeTestPDF() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { context in
            context.beginPage()
            let text = "Integration Test Flight Plan" as NSString
            text.draw(at: CGPoint(x: 72, y: 72), withAttributes: [
                .font: UIFont.systemFont(ofSize: 14)
            ])
        }
    }

    /// Creates a test booking owned by the test user and returns its ID.
    /// The booking has the test user as both customer and pilot with 'accepted' status.
    private func createTestBooking() async throws -> UUID {
        let bookingId = UUID()

        let booking: [String: AnyJSON] = [
            "id": .string(bookingId.uuidString),
            "customer_id": .string(TestUser.id.uuidString),
            "pilot_id": .string(TestUser.id.uuidString),
            "location_lat": .double(37.7749),
            "location_lng": .double(-122.4194),
            "location_name": .string("Test Location, CA"),
            "description": .string("Integration test booking for flight plan"),
            "payment_amount": .double(100),
            "status": .string("accepted"),
            "is_internal_test": .bool(true)
        ]

        try await supabase
            .from("bookings")
            .insert(booking)
            .execute()

        // Schedule cleanup — delete booking (cascades to flight_plans and booking_checklists)
        addTeardownBlock { [supabase] in
            try? await supabase
                .from("bookings")
                .delete()
                .eq("id", value: bookingId.uuidString)
                .execute()
        }

        return bookingId
    }

    /// Builds a minimal FlightPlanFormData for testing.
    private func makeTestFormData() -> FlightPlanFormData {
        FlightPlanFormData(
            pilotName: "Test Pilot",
            pilotLicenseNumber: "TEST-107-001",
            callSign: "TESTCALL",
            droneManufacturer: "DJI",
            droneModel: "Mavic 3",
            droneSerialNumber: "SN-TEST-12345",
            droneRegistrationNumber: "FA-TEST-001",
            takeoffDateTime: Date(),
            location: "Test Location, CA",
            latitude: "37.7749",
            longitude: "-122.4194",
            regulatoryAuthority: .faa,
            maxAltitudeFeet: 400,
            airspaceClass: .classG,
            laancGridCeiling: nil,
            laancAuthorizationStatus: .notApplicable,
            flightOverPeople: false,
            flightOverPeopleExplanation: nil,
            vlosType: .vlos,
            part107Compliant: true,
            part107NonComplianceExplanation: nil,
            requiresWaiver: false,
            waiverSafetyMitigations: nil,
            waiverOperationalProcedures: nil,
            waiverRiskAnalysis: nil,
            certificationRegulation: .part107,
            signatureImage: nil,
            signatureDate: Date(),
            generatedAt: Date()
        )
    }

    // =========================================================
    // MARK: - Flight Plan Storage Upload Tests
    // =========================================================

    func testFlightPlanStorage_uploadPDF() async throws {
        let pdfData = makeTestPDF()
        let bookingId = UUID()
        let timestamp = Int(Date().timeIntervalSince1970)
        let filePath = "\(userFolder)/\(bookingId.uuidString.lowercased())/\(timestamp)_flight_plan.pdf"

        _ = try await supabase.storage
            .from("flight-plans")
            .upload(
                filePath,
                data: pdfData,
                options: FileOptions(contentType: "application/pdf")
            )

        addTeardownBlock { [supabase] in
            try? await supabase.storage
                .from("flight-plans")
                .remove(paths: [filePath])
        }

        // Verify download (private bucket — only owner can read)
        let downloaded = try await supabase.storage
            .from("flight-plans")
            .download(path: filePath)
        XCTAssertGreaterThan(downloaded.count, 0, "Downloaded flight plan PDF should not be empty")
    }

    func testFlightPlanStorage_cannotUploadToOtherUsersFolder() async throws {
        let otherUserId = UUID()
        let pdfData = makeTestPDF()
        let filePath = "\(otherUserId.uuidString.lowercased())/\(UUID().uuidString.lowercased())/test_flight_plan.pdf"

        do {
            _ = try await supabase.storage
                .from("flight-plans")
                .upload(
                    filePath,
                    data: pdfData,
                    options: FileOptions(contentType: "application/pdf")
                )
            try? await supabase.storage
                .from("flight-plans")
                .remove(paths: [filePath])
            XCTFail("RLS should block upload to another user's flight-plans folder")
        } catch {
            // Expected — RLS blocked the upload
        }
    }

    // =========================================================
    // MARK: - Flight Plan Full Service Round-Trip
    // =========================================================

    func testFlightPlanService_uploadRoundTrip() async throws {
        let bookingId = try await createTestBooking()
        let formData = makeTestFormData()
        let pdfData = makeTestPDF()

        // Upload via the service (storage upload + DB insert)
        let pdfUrl = try await flightPlanService.uploadFlightPlan(
            pdfData: pdfData,
            formData: formData,
            pilotId: TestUser.id,
            bookingId: bookingId
        )

        XCTAssertFalse(pdfUrl.isEmpty, "Should return a PDF URL")
        XCTAssertTrue(pdfUrl.contains("flight-plans"), "URL should reference the flight-plans bucket")

        // Verify the database record exists
        struct FlightPlanRow: Decodable {
            let id: UUID
            let pilotName: String
            let callSign: String
            let location: String
            let regulatoryAuthority: String
            let maxAltitudeFeet: Int
            let airspaceClass: String
            let vlosType: String
            let pdfUrl: String

            enum CodingKeys: String, CodingKey {
                case id
                case pilotName = "pilot_name"
                case callSign = "call_sign"
                case location
                case regulatoryAuthority = "regulatory_authority"
                case maxAltitudeFeet = "max_altitude_feet"
                case airspaceClass = "airspace_class"
                case vlosType = "vlos_type"
                case pdfUrl = "pdf_url"
            }
        }

        let rows: [FlightPlanRow] = try await supabase
            .from("flight_plans")
            .select()
            .eq("booking_id", value: bookingId.uuidString)
            .eq("pilot_id", value: TestUser.id.uuidString)
            .execute()
            .value

        XCTAssertEqual(rows.count, 1, "Should have exactly one flight plan record")
        let row = rows[0]
        XCTAssertEqual(row.pilotName, "Test Pilot")
        XCTAssertEqual(row.callSign, "TESTCALL")
        XCTAssertEqual(row.location, "Test Location, CA")
        XCTAssertEqual(row.regulatoryAuthority, "FAA")
        XCTAssertEqual(row.maxAltitudeFeet, 400)
        XCTAssertEqual(row.airspaceClass, "G")
        XCTAssertEqual(row.vlosType, "VLOS")
        XCTAssertEqual(row.pdfUrl, pdfUrl)

        // Clean up storage file
        let urlPath = URL(string: pdfUrl)?.path ?? ""
        let storagePrefix = "/storage/v1/object/public/flight-plans/"
        if urlPath.hasPrefix(storagePrefix) {
            let storagePath = String(urlPath.dropFirst(storagePrefix.count))
            try? await supabase.storage
                .from("flight-plans")
                .remove(paths: [storagePath])
        }
    }

    func testFlightPlanService_immutableRecord() async throws {
        let bookingId = try await createTestBooking()
        let formData = makeTestFormData()
        let pdfData = makeTestPDF()

        let pdfUrl = try await flightPlanService.uploadFlightPlan(
            pdfData: pdfData,
            formData: formData,
            pilotId: TestUser.id,
            bookingId: bookingId
        )

        // Fetch the flight plan ID
        struct IdRow: Decodable { let id: UUID }
        let rows: [IdRow] = try await supabase
            .from("flight_plans")
            .select("id")
            .eq("booking_id", value: bookingId.uuidString)
            .execute()
            .value
        guard let flightPlanId = rows.first?.id else {
            XCTFail("Flight plan record not found")
            return
        }

        // Attempt to UPDATE — should be blocked by RLS ("Flight plans cannot be updated")
        do {
            try await supabase
                .from("flight_plans")
                .update(["location": "Hacked Location"])
                .eq("id", value: flightPlanId.uuidString)
                .execute()
            // PostgREST may return 200 with 0 rows (RLS filter), which is acceptable
        } catch {
            // RLS explicitly blocked — also acceptable
        }

        // Verify location is unchanged
        struct LocationRow: Decodable { let location: String }
        let afterUpdate: [LocationRow] = try await supabase
            .from("flight_plans")
            .select("location")
            .eq("id", value: flightPlanId.uuidString)
            .execute()
            .value
        XCTAssertEqual(afterUpdate.first?.location, "Test Location, CA",
                       "Flight plan should be immutable — location must not change")

        // Clean up storage
        let urlPath = URL(string: pdfUrl)?.path ?? ""
        let storagePrefix = "/storage/v1/object/public/flight-plans/"
        if urlPath.hasPrefix(storagePrefix) {
            let storagePath = String(urlPath.dropFirst(storagePrefix.count))
            try? await supabase.storage
                .from("flight-plans")
                .remove(paths: [storagePath])
        }
    }

    // =========================================================
    // MARK: - Flight Plan PDF Generation
    // =========================================================

    func testFlightPlanService_generatePDF() async throws {
        let formData = makeTestFormData()

        let pdfData = flightPlanService.generatePDF(from: formData)
        XCTAssertNotNil(pdfData, "PDF generation should succeed")
        XCTAssertGreaterThan(pdfData?.count ?? 0, 100, "Generated PDF should have meaningful content")

        // Verify it's a valid PDF (starts with %PDF)
        if let data = pdfData {
            let header = String(data: data.prefix(5), encoding: .ascii)
            XCTAssertEqual(header, "%PDF-", "Generated data should be a valid PDF")
        }
    }
}
