//
//  BookingService.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import Foundation
import Supabase
import CoreLocation
import Combine

extension Notification.Name {
    static let bookingDidChange = Notification.Name("BookingDidChange")
}

protocol BookingBackend {
    func createBooking(payload: [String: AnyJSON], bookingId: UUID) async throws -> Booking
    func fetchBooking(id: UUID) async throws -> Booking
    func updateBooking(id: UUID, values: [String: AnyJSON]) async throws
    func joinAutomotiveBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse
    func fetchUserProfile(userId: UUID) async throws -> UserProfile
    // S&R crew operations
    func joinSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse
    func leaveSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse
    func fetchBookingCrew(bookingId: UUID) async throws -> [BookingCrewMember]
}

protocol BookingNotificationManaging {
    func notifyBookingAccepted(bookingId: UUID, pilotCallSign: String, aircraftType: String, departureTime: Date) async
    func scheduleBookingReminder(bookingId: UUID, aircraftType: String, departureTime: Date, pilotCallSign: String) async
    func notifyNearbyBooking(bookingId: UUID, aircraftType: String, distance: Double, departureTime: Date) async
    func notifyCrewBookingCompleted(bookingId: UUID, payoutAmount: Decimal, role: String) async
    func notifyBookingCancelled(bookingId: UUID, cancelledByName: String, aircraftType: String) async
    func notifyTipReceived(bookingId: UUID, tipAmount: Decimal, customerName: String) async
    func notifyPayoutConfirmation(bookingId: UUID, payoutAmount: Decimal) async
    func notifyBeaconAccepted(bookingId: UUID, volunteerCallSign: String, missionType: String) async
    func notifyBeaconResolved(bookingId: UUID, missionType: String) async
}

protocol NotificationPreferencesProviding {
    var preferences: NotificationPreferences { get }
    func loadPreferences(userId: UUID) async throws
}

@MainActor
class BookingService: ObservableObject {
    @Published var availableBookings: [Booking] = []
    @Published var myBookings: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    private let backend: BookingBackend
    private let notificationManager: BookingNotificationManaging
    private let notificationPreferencesService: NotificationPreferencesProviding
    private let skipNetworkCalls: Bool
    private let defaultPilotSearchRadiusMiles: Double = 25.0
    private let metersPerMile: Double = 1609.34

    init(
        backend: BookingBackend? = nil,
        notificationManager: BookingNotificationManaging? = nil,
        notificationPreferencesService: NotificationPreferencesProviding? = nil,
        skipNetworkCalls: Bool = false
    ) {
        self.backend = backend ?? SupabaseBookingBackend()
        self.notificationManager = notificationManager ?? NotificationManager.shared
        self.notificationPreferencesService = notificationPreferencesService ?? NotificationPreferencesService()
        self.skipNetworkCalls = skipNetworkCalls
    }

    private func publishBookingChange(for bookingId: UUID) {
        NotificationCenter.default.post(name: .bookingDidChange, object: bookingId)
    }

    private func excludeJoinedCrewBookings(from bookings: [Booking], pilotId: UUID) async -> [Booking] {
        guard let memberships = try? await fetchPilotCrewMemberships(pilotId: pilotId) else {
            return bookings
        }

        let joinedBookingIds = Set(memberships.map(\.bookingId))
        guard !joinedBookingIds.isEmpty else {
            return bookings
        }
        return bookings.filter { !joinedBookingIds.contains($0.id) }
    }
    
    // MARK: - Create Booking (Customer)
    
    func createBooking(
        customerId: UUID,
        location: CLLocationCoordinate2D,
        locationName: String,
        scheduledDate: Date?,
        endDate: Date? = nil,
        specialization: BookingSpecialization?,
        description: String?,
        paymentAmount: Decimal,
        estimatedFlightHours: Double,
        requiredMinimumRank: Int = 0,
        paymentIntentId: String? = nil,
        chargeId: String? = nil
    ) async throws -> Booking {
        isLoading = true
        errorMessage = nil
        
        do {
            let bookingId = UUID()
            var booking: [String: AnyJSON] = [
                "id": .string(bookingId.uuidString),
                "customer_id": .string(customerId.uuidString),
                "location_lat": .double(location.latitude),
                "location_lng": .double(location.longitude),
                "location_name": .string(locationName),
                "payment_amount": .double(NSDecimalNumber(decimal: paymentAmount).doubleValue),
                "status": .string(BookingStatus.available.rawValue),
                "created_at": .string(ISO8601DateFormatter().string(from: Date())),
                "estimated_flight_hours": .double(estimatedFlightHours),
                "required_minimum_rank": .integer(requiredMinimumRank)
            ]
            
            if let description = description, !description.isEmpty {
                booking["description"] = .string(description)
            }
            
            if let scheduledDate = scheduledDate {
                booking["scheduled_date"] = .string(ISO8601DateFormatter().string(from: scheduledDate))
            }
            
            if let endDate = endDate {
                booking["end_date"] = .string(ISO8601DateFormatter().string(from: endDate))
            }
            
            if let specialization = specialization {
                booking["specialization"] = .string(specialization.rawValue)
            }
            
            if let paymentIntentId = paymentIntentId {
                booking["payment_intent_id"] = .string(paymentIntentId)
            }
            
            if let chargeId = chargeId {
                booking["charge_id"] = .string(chargeId)
            }

            // Set expiration: scheduledDate if provided, otherwise created_at + 7 days
            let expiresAt: Date
            if let scheduledDate = scheduledDate {
                expiresAt = scheduledDate
            } else {
                expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days from now
            }
            booking["expires_at"] = .string(ISO8601DateFormatter().string(from: expiresAt))
            booking["expiration_notified"] = .bool(false)

            // Insert + fetch via backend so tests can inject a mock
            let createdBooking = try await backend.createBooking(payload: booking, bookingId: bookingId)
            
            // Fire-and-forget: notification should complete even if caller is cancelled
            if !skipNetworkCalls {
                Task { [createdBooking] in
                    await notifyNearbyPilotsAboutNewBooking(booking: createdBooking)
                }
            }

            isLoading = false
            return createdBooking
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Create Search & Rescue Booking (Customer)
    
    /// Creates a Search & Rescue booking without upfront payment.
    /// Payment is calculated after mission completion based on hours worked and pilots involved.
    func createSearchRescueBooking(
        customerId: UUID,
        location: CLLocationCoordinate2D,
        locationName: String,
        scheduledDate: Date?,
        endDate: Date? = nil,
        description: String?,
        isVoluntary: Bool,
        hourlyRate: Decimal,
        estimatedFlightHours: Double,
        assignmentType: SARAssignmentType? = nil,
        governmentAgency: GovernmentAgency? = nil,
        usesBeaconProgram: Bool = false,
        requiredMinimumRank: Int = 0,
        numberOfPilots: Int = 1
    ) async throws -> Booking {
        isLoading = true
        errorMessage = nil
        
        do {
            let bookingId = UUID()
            var booking: [String: AnyJSON] = [
                "id": .string(bookingId.uuidString),
                "customer_id": .string(customerId.uuidString),
                "location_lat": .double(location.latitude),
                "location_lng": .double(location.longitude),
                "location_name": .string(locationName),
                "specialization": .string(BookingSpecialization.searchRescue.rawValue),
                "description": .string(description ?? ""), // Always include description (required by NOT NULL constraint)
                "payment_amount": .double(NSDecimalNumber(decimal: hourlyRate * Decimal(estimatedFlightHours) * Decimal(numberOfPilots)).doubleValue), // Calculate total payment
                "status": .string(BookingStatus.available.rawValue),
                "created_at": .string(ISO8601DateFormatter().string(from: Date())),
                "estimated_flight_hours": .double(estimatedFlightHours),
                "required_minimum_rank": .integer(requiredMinimumRank),
                "is_voluntary": .bool(isVoluntary),
                "hourly_rate": .double(NSDecimalNumber(decimal: hourlyRate).doubleValue),
                "uses_beacon_program": .bool(usesBeaconProgram),
                "number_of_pilots": .integer(numberOfPilots)
            ]
            
            if let scheduledDate = scheduledDate {
                booking["scheduled_date"] = .string(ISO8601DateFormatter().string(from: scheduledDate))
            }
            
            if let endDate = endDate {
                booking["end_date"] = .string(ISO8601DateFormatter().string(from: endDate))
            }
            
            if let assignmentType = assignmentType {
                booking["assignment_type"] = .string(assignmentType.rawValue)
            }
            
            if let governmentAgency = governmentAgency {
                booking["government_agency"] = .string(governmentAgency.rawValue)
            }

            // Set expiration: scheduledDate if provided, otherwise created_at + 7 days
            let expiresAt: Date
            if let scheduledDate = scheduledDate {
                expiresAt = scheduledDate
            } else {
                expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days from now
            }
            booking["expires_at"] = .string(ISO8601DateFormatter().string(from: expiresAt))
            booking["expiration_notified"] = .bool(false)

            // Insert + fetch via backend
            let createdBooking = try await backend.createBooking(payload: booking, bookingId: bookingId)
            
            // Fire-and-forget: notification should complete even if caller is cancelled
            if !skipNetworkCalls {
                Task { [createdBooking] in
                    await notifyNearbyPilotsAboutNewBooking(booking: createdBooking)
                }
            }

            isLoading = false
            return createdBooking
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Update Booking (Customer)
    
    func updateBooking(
        bookingId: UUID,
        location: CLLocationCoordinate2D,
        locationName: String,
        scheduledDate: Date?,
        endDate: Date? = nil,
        specialization: BookingSpecialization?,
        description: String?,
        paymentAmount: Decimal,
        estimatedFlightHours: Double,
        requiredMinimumRank: Int = 0
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            var updates: [String: AnyJSON] = [
                "location_lat": .double(location.latitude),
                "location_lng": .double(location.longitude),
                "location_name": .string(locationName),
                "payment_amount": .double(NSDecimalNumber(decimal: paymentAmount).doubleValue),
                "estimated_flight_hours": .double(estimatedFlightHours),
                "required_minimum_rank": .integer(requiredMinimumRank)
            ]
            
            if let description = description, !description.isEmpty {
                updates["description"] = .string(description)
            } else {
                // Allow clearing description by setting to null
                updates["description"] = .null
            }
            
            if let scheduledDate = scheduledDate {
                updates["scheduled_date"] = .string(ISO8601DateFormatter().string(from: scheduledDate))
            }
            
            if let endDate = endDate {
                updates["end_date"] = .string(ISO8601DateFormatter().string(from: endDate))
            }
            
            if let specialization = specialization {
                updates["specialization"] = .string(specialization.rawValue)
            }
            
            try await supabase
                .from("bookings")
                .update(updates)
                .eq("id", value: bookingId.uuidString)
                .execute()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func fetchBooking(id: UUID) async throws -> Booking {
        try await backend.fetchBooking(id: id)
    }
    
    // MARK: - Fetch Available Bookings (Pilot)
    
    func fetchAvailableBookings(forPilotId pilotId: UUID? = nil) async throws {
        isLoading = true
        errorMessage = nil
        
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // Simulate API call delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // SAMPLE DATA FOR DEMO PURPOSES
            let sampleBookings = createSampleAvailableBookings()
            
            await MainActor.run {
                self.availableBookings = sampleBookings
                self.isLoading = false
            }
            return
        }
        
        // Real backend call
        do {
            // Fetch available bookings from database (status = available)
            var bookings: [Booking] = try await supabase
                .from("bookings")
                .select()
                .eq("status", value: BookingStatus.available.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // If pilot ID provided, filter bookings based on pilot eligibility
            if let pilotId = pilotId {
                bookings = try await filterBookingsForPilot(bookings: bookings, pilotId: pilotId)
                bookings = await excludeJoinedCrewBookings(from: bookings, pilotId: pilotId)
            }
            
            await MainActor.run {
                self.availableBookings = bookings
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Filter bookings based on pilot's rank eligibility
    /// - Ensigns (rank 0) cannot see automotive bookings
    /// - If automotive booking has 3/4 crew with no qualified lead, only show to pilots who can be lead
    /// - Filter out internal test bookings for pilots without @buzzbuzzin.com email
    private func filterBookingsForPilot(bookings: [Booking], pilotId: UUID) async throws -> [Booking] {
        // Get pilot's rank and email
        let pilotStats: PilotStats? = try? await supabase
            .from("pilot_stats")
            .select()
            .eq("pilot_id", value: pilotId.uuidString)
            .single()
            .execute()
            .value
        
        let pilotProfile: UserProfile? = try? await supabase
            .from("profiles")
            .select()
            .eq("id", value: pilotId.uuidString)
            .single()
            .execute()
            .value
        
        let pilotRank = pilotStats?.tier ?? 0
        let pilotEmail = pilotProfile?.email ?? ""
        let isBuzzEmployee = pilotEmail.hasSuffix("@buzzbuzzin.com")
        
        var filteredBookings: [Booking] = []
        
        for booking in bookings {
            // Filter out internal test bookings for non-Buzz employees
            if booking.isInternalTest == true && !isBuzzEmployee {
                continue // Skip this internal test booking
            }
            
            // For automotive bookings, apply rank-based filtering
            if booking.isAutomotiveCrewBooking {
                // Ensigns (rank 0) cannot participate in automotive bookings
                if pilotRank < 1 {
                    continue // Skip this booking
                }
                
                // Check crew status to see if last seat is reserved
                do {
                    let crewInfo = try await fetchBookingCrew(
                        bookingId: booking.id,
                        requesterId: pilotId,
                        requesterType: "pilot"
                    )
                    
                    // Get minimum lead rank from booking (default to 2 = Lieutenant)
                    let minLeadRank = booking.requiredMinimumRank ?? 2
                    
                    // If last seat is reserved (3/4 crew, no qualified lead)
                    if crewInfo.crewCount == 3 && !(crewInfo.hasQualifiedLead ?? false) {
                        // Only show to pilots who can be lead
                        if pilotRank < minLeadRank {
                            continue // Skip - last seat reserved for qualified leads
                        }
                    }
                } catch {
                    // If we can't fetch crew info, include the booking (fail open)
                    print("Error fetching crew info for booking \(booking.id): \(error)")
                }
            }
            
            filteredBookings.append(booking)
        }
        
        return filteredBookings
    }
    
    // MARK: - Sample Data for Demo (Available Bookings)
    // TODO: Remove this function when connecting to real backend
    
    private func createSampleAvailableBookings() -> [Booking] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: nil,
                locationLat: 37.7749,
                locationLng: -122.4194,
                locationName: "Golden Gate Bridge, San Francisco",
                scheduledDate: calendar.date(byAdding: .day, value: 3, to: now),
                endDate: calendar.date(byAdding: .day, value: 3, to: now)?.addingTimeInterval(3600 * 4),
                specialization: .realEstate,
                description: "Aerial photography shoot for real estate listing. Need high-quality shots of the property and surrounding area.",
                paymentAmount: Decimal(850.00),
                tipAmount: nil,
                status: .available,
                createdAt: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
                estimatedFlightHours: 3.5,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 1
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: nil,
                locationLat: 34.0522,
                locationLng: -118.2437,
                locationName: "Hollywood Hills, Los Angeles",
                scheduledDate: calendar.date(byAdding: .day, value: 5, to: now),
                endDate: calendar.date(byAdding: .day, value: 5, to: now)?.addingTimeInterval(3600 * 6),
                specialization: .motionPicture,
                description: "Cinematic drone footage needed for independent film production. Must have experience with cinematic movements and color grading.",
                paymentAmount: Decimal(1500.00),
                tipAmount: nil,
                status: .available,
                createdAt: calendar.date(byAdding: .hour, value: -5, to: now) ?? now,
                estimatedFlightHours: 6.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: nil,
                locationLat: 40.7128,
                locationLng: -74.0060,
                locationName: "Brooklyn Bridge, New York",
                scheduledDate: calendar.date(byAdding: .day, value: 7, to: now),
                endDate: calendar.date(byAdding: .day, value: 7, to: now)?.addingTimeInterval(3600 * 2),
                specialization: .inspections,
                description: "Bridge inspection for maintenance assessment. Need detailed footage of structural elements and any visible wear.",
                paymentAmount: Decimal(1200.00),
                tipAmount: nil,
                status: .available,
                createdAt: calendar.date(byAdding: .hour, value: -1, to: now) ?? now,
                estimatedFlightHours: 2.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: nil,
                locationLat: 41.8781,
                locationLng: -87.6298,
                locationName: "Millennium Park, Chicago",
                scheduledDate: calendar.date(byAdding: .day, value: 2, to: now),
                endDate: calendar.date(byAdding: .day, value: 2, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .realEstate,
                description: "Event coverage for outdoor concert. Need dynamic aerial shots throughout the event duration.",
                paymentAmount: Decimal(650.00),
                tipAmount: nil,
                status: .available,
                createdAt: calendar.date(byAdding: .hour, value: -8, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: nil,
                locationLat: 39.9526,
                locationLng: -75.1652,
                locationName: "Independence Hall, Philadelphia",
                scheduledDate: calendar.date(byAdding: .day, value: 10, to: now),
                endDate: calendar.date(byAdding: .day, value: 10, to: now)?.addingTimeInterval(3600 * 4),
                specialization: .inspections,
                description: "3D mapping and surveying for historical site documentation. Photogrammetry experience required.",
                paymentAmount: Decimal(1800.00),
                tipAmount: nil,
                status: .available,
                createdAt: calendar.date(byAdding: .hour, value: -12, to: now) ?? now,
                estimatedFlightHours: 4.5,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: nil,
                locationLat: 29.7604,
                locationLng: -95.3698,
                locationName: "Downtown Houston, Texas",
                scheduledDate: calendar.date(byAdding: .day, value: 4, to: now),
                endDate: calendar.date(byAdding: .day, value: 4, to: now)?.addingTimeInterval(3600 * 5),
                specialization: .agriculture,
                description: "Crop monitoring and field analysis for large farm. Need multispectral imaging capabilities.",
                paymentAmount: Decimal(950.00),
                tipAmount: nil,
                status: .available,
                createdAt: calendar.date(byAdding: .hour, value: -3, to: now) ?? now,
                estimatedFlightHours: 5.0,
                pilotRated: nil,
                customerRated: nil
            ),
        ]
    }
    
    // MARK: - Fetch My Bookings
    
    func fetchMyBookings(userId: UUID, isPilot: Bool) async throws {
        isLoading = true
        errorMessage = nil
        
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // Simulate API call delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // SAMPLE DATA FOR DEMO PURPOSES
            let sampleBookings: [Booking]
            if isPilot {
                sampleBookings = createSamplePilotBookings()
            } else {
                sampleBookings = createSampleCustomerBookings()
            }
            
            await MainActor.run {
                self.myBookings = sampleBookings
                self.isLoading = false
            }
            return
        }
        
        // Store current bookings to preserve them if fetch fails
        let previousBookings = myBookings
        
        do {
            // Fetch real bookings from database
            let query = supabase
                .from("bookings")
                .select()
            
            let realBookings: [Booking]
            if isPilot {
                // Fetch bookings where pilot is assigned
                let pilotBookings: [Booking] = try await query
                    .eq("pilot_id", value: userId.uuidString)
                    .in("status", values: [BookingStatus.accepted.rawValue, BookingStatus.staffed.rawValue, BookingStatus.inProgress.rawValue, BookingStatus.completed.rawValue])
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                
                // Also fetch automotive bookings where pilot is a crew member
                let crewMemberships: [BookingCrewMember] = try await supabase
                    .from("booking_crew")
                    .select()
                    .eq("pilot_id", value: userId.uuidString)
                    .execute()
                    .value
                
                let crewBookingIds = crewMemberships.map { $0.bookingId.uuidString }
                var crewBookings: [Booking] = []
                
                if !crewBookingIds.isEmpty {
                    crewBookings = try await supabase
                        .from("bookings")
                        .select()
                        .in("id", values: crewBookingIds)
                        .in("status", values: [BookingStatus.available.rawValue, BookingStatus.accepted.rawValue, BookingStatus.staffed.rawValue, BookingStatus.inProgress.rawValue, BookingStatus.completed.rawValue])
                        .execute()
                        .value
                }
                
                // Combine and deduplicate bookings
                var allBookings = pilotBookings
                for crewBooking in crewBookings {
                    if !allBookings.contains(where: { $0.id == crewBooking.id }) {
                        allBookings.append(crewBooking)
                    }
                }
                
                // Filter out internal test bookings for non-Buzz pilots
                let pilotProfile: UserProfile? = try? await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                let pilotEmail = pilotProfile?.email ?? ""
                let isBuzzEmployee = pilotEmail.hasSuffix("@buzzbuzzin.com")
                
                // Filter out internal test bookings if pilot is not a Buzz employee
                if !isBuzzEmployee {
                    allBookings = allBookings.filter { booking in
                        booking.isInternalTest != true
                    }
                }
                
                // Sort by created_at descending
                realBookings = allBookings.sorted { $0.createdAt > $1.createdAt }
            } else {
                realBookings = try await query
                    .eq("customer_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }
            
            await MainActor.run {
                self.myBookings = realBookings
                self.isLoading = false
            }
        } catch {
            // Check if error is a cancellation (not a real error)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // Request was cancelled (e.g., during refresh, navigation, or view dismissal)
                // Don't treat this as an error - preserve existing bookings
                print("Booking fetch was cancelled (likely due to concurrent request or navigation)")
                await MainActor.run {
                    // Keep existing bookings, don't replace with demo data
                    self.isLoading = false
                }
                return
            }
            
            // If database fetch fails with a real error, log and preserve previous bookings
            print("Error fetching bookings from database: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // If we have previous bookings (from a successful fetch), preserve them
            // Otherwise, show empty list
            let bookingsToShow: [Booking]
            if !previousBookings.isEmpty {
                // Keep previous bookings
                bookingsToShow = previousBookings
            } else {
                // No previous bookings, show empty list
                bookingsToShow = []
            }
            
            await MainActor.run {
                self.myBookings = bookingsToShow
                self.isLoading = false
                // Don't set errorMessage to avoid showing error to user
                // since we're preserving existing bookings
            }
        }
    }
    
    // MARK: - Sample Data for Demo (Pilot's Bookings)
    // TODO: Remove this function when connecting to real backend
    
    private func createSamplePilotBookings() -> [Booking] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            // Active (Accepted) Bookings
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(), // Current pilot
                locationLat: 37.7849,
                locationLng: -122.4094,
                locationName: "Coit Tower, San Francisco",
                scheduledDate: calendar.date(byAdding: .day, value: 1, to: now),
                endDate: calendar.date(byAdding: .day, value: 1, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .realEstate,
                description: "Real estate photography for luxury apartment complex. Need professional shots showing amenities and views.",
                paymentAmount: Decimal(750.00),
                tipAmount: nil,
                status: .accepted,
                createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(), // Current pilot
                locationLat: 34.0522,
                locationLng: -118.2437,
                locationName: "Griffith Observatory, Los Angeles",
                scheduledDate: calendar.date(byAdding: .day, value: 6, to: now),
                endDate: calendar.date(byAdding: .day, value: 6, to: now)?.addingTimeInterval(3600 * 5),
                specialization: .motionPicture,
                description: "Cinematic B-roll footage for documentary film. Sunset shots preferred.",
                paymentAmount: Decimal(1200.00),
                tipAmount: nil,
                status: .accepted,
                createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                estimatedFlightHours: 5.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            // Completed Bookings
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(), // Current pilot
                locationLat: 40.7580,
                locationLng: -73.9855,
                locationName: "Central Park, New York",
                scheduledDate: calendar.date(byAdding: .day, value: -10, to: now),
                endDate: calendar.date(byAdding: .day, value: -10, to: now)?.addingTimeInterval(3600 * 4),
                specialization: .realEstate,
                description: "Event coverage for outdoor festival. Multiple flight sessions throughout the day.",
                paymentAmount: Decimal(850.00),
                tipAmount: Decimal(100.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -15, to: now) ?? now,
                estimatedFlightHours: 4.0,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(), // Current pilot
                locationLat: 41.8781,
                locationLng: -87.6298,
                locationName: "Navy Pier, Chicago",
                scheduledDate: calendar.date(byAdding: .day, value: -20, to: now),
                endDate: calendar.date(byAdding: .day, value: -20, to: now)?.addingTimeInterval(3600 * 2),
                specialization: .realEstate,
                description: "Aerial shots for property development project. Showcase the waterfront location.",
                paymentAmount: Decimal(950.00),
                tipAmount: Decimal(50.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -25, to: now) ?? now,
                estimatedFlightHours: 2.0,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(), // Current pilot
                locationLat: 25.7617,
                locationLng: -80.1918,
                locationName: "South Beach, Miami",
                scheduledDate: calendar.date(byAdding: .day, value: -30, to: now),
                endDate: calendar.date(byAdding: .day, value: -30, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .motionPicture,
                description: "Beachfront cinematography for commercial advertisement. Golden hour preferred.",
                paymentAmount: Decimal(1400.00),
                tipAmount: Decimal(200.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -35, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(), // Current pilot
                locationLat: 47.6062,
                locationLng: -122.3321,
                locationName: "Space Needle, Seattle",
                scheduledDate: calendar.date(byAdding: .day, value: -45, to: now),
                endDate: calendar.date(byAdding: .day, value: -45, to: now)?.addingTimeInterval(3600 * 2),
                specialization: .inspections,
                description: "Rooftop inspection for building maintenance. Detailed structural assessment needed.",
                paymentAmount: Decimal(1100.00),
                tipAmount: nil,
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -50, to: now) ?? now,
                estimatedFlightHours: 2.0,
                pilotRated: true,
                customerRated: true
            )
        ]
    }
    
    // MARK: - Sample Data for Demo (Customer's Bookings)
    // TODO: Remove this function when connecting to real backend
    
    private func createSampleCustomerBookings() -> [Booking] {
        let calendar = Calendar.current
        let now = Date()
        
        // Create consistent pilot IDs for demo (these will map to different sample pilot profiles)
        // The ProfileService will hash these UUIDs to select from 10 sample pilots
        // Using fixed UUIDs ensures consistency across app sessions
        let pilot1Id = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let pilot2Id = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
        let pilot3Id = UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID()
        
        return [
            // Available Bookings (No pilot assigned yet)
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: nil,
                locationLat: 37.7749,
                locationLng: -122.4194,
                locationName: "Golden Gate Bridge, San Francisco",
                scheduledDate: calendar.date(byAdding: .day, value: 3, to: now),
                endDate: calendar.date(byAdding: .day, value: 3, to: now)?.addingTimeInterval(3600 * 4),
                specialization: .motionPicture,
                description: "Aerial cinematography for tourism video. Need stunning shots of the bridge and surrounding bay area.",
                paymentAmount: Decimal(1500.00),
                tipAmount: nil,
                status: .available,
                createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                estimatedFlightHours: 4.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: nil,
                locationLat: 40.7128,
                locationLng: -74.0060,
                locationName: "Brooklyn Bridge, New York",
                scheduledDate: calendar.date(byAdding: .day, value: 7, to: now),
                endDate: calendar.date(byAdding: .day, value: 7, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .realEstate,
                description: "Real estate photography for luxury condominium project. Showcase views and architecture.",
                paymentAmount: Decimal(1100.00),
                tipAmount: nil,
                status: .available,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: nil,
                locationLat: 41.8781,
                locationLng: -87.6298,
                locationName: "Millennium Park, Chicago",
                scheduledDate: calendar.date(byAdding: .day, value: 10, to: now),
                endDate: calendar.date(byAdding: .day, value: 10, to: now)?.addingTimeInterval(3600 * 2),
                specialization: .droneArt,
                description: "Creative aerial art project for public installation. Abstract patterns and geometric designs.",
                paymentAmount: Decimal(800.00),
                tipAmount: nil,
                status: .available,
                createdAt: now,
                estimatedFlightHours: 2.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            
            // Accepted Bookings (Pilot assigned, can message)
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: pilot1Id,
                locationLat: 34.0522,
                locationLng: -118.2437,
                locationName: "Hollywood Hills, Los Angeles",
                scheduledDate: calendar.date(byAdding: .day, value: 1, to: now),
                endDate: calendar.date(byAdding: .day, value: 1, to: now)?.addingTimeInterval(3600 * 5),
                specialization: .motionPicture,
                description: "Film production B-roll footage. Need dramatic landscape shots for opening sequence.",
                paymentAmount: Decimal(1800.00),
                tipAmount: nil,
                status: .accepted,
                createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                estimatedFlightHours: 5.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: pilot2Id,
                locationLat: 39.9526,
                locationLng: -75.1652,
                locationName: "Independence Hall, Philadelphia",
                scheduledDate: calendar.date(byAdding: .day, value: 5, to: now),
                endDate: calendar.date(byAdding: .day, value: 5, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .realEstate,
                description: "Historical building documentation for preservation project. Detailed architectural shots required.",
                paymentAmount: Decimal(950.00),
                tipAmount: nil,
                status: .accepted,
                createdAt: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: nil,
                customerRated: nil,
                requiredMinimumRank: 0
            ),
            
            // Completed Bookings (Finished, can rate pilot)
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: pilot1Id,
                locationLat: 40.7580,
                locationLng: -73.9855,
                locationName: "Central Park, New York",
                scheduledDate: calendar.date(byAdding: .day, value: -7, to: now),
                endDate: calendar.date(byAdding: .day, value: -7, to: now)?.addingTimeInterval(3600 * 4),
                specialization: .motionPicture,
                description: "Event coverage for outdoor concert. Multiple aerial angles and crowd shots.",
                paymentAmount: Decimal(1200.00),
                tipAmount: Decimal(150.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -12, to: now) ?? now,
                estimatedFlightHours: 4.0,
                pilotRated: nil,
                customerRated: false, // Not rated yet - can rate
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: pilot2Id,
                locationLat: 41.8781,
                locationLng: -87.6298,
                locationName: "Navy Pier, Chicago",
                scheduledDate: calendar.date(byAdding: .day, value: -15, to: now),
                endDate: calendar.date(byAdding: .day, value: -15, to: now)?.addingTimeInterval(3600 * 2),
                specialization: .realEstate,
                description: "Waterfront property marketing video. Showcase pier attractions and lake views.",
                paymentAmount: Decimal(900.00),
                tipAmount: Decimal(100.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -20, to: now) ?? now,
                estimatedFlightHours: 2.0,
                pilotRated: nil,
                customerRated: true // Already rated
            ),
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: pilot3Id,
                locationLat: 29.7604,
                locationLng: -95.3698,
                locationName: "Downtown Houston, Texas",
                scheduledDate: calendar.date(byAdding: .day, value: -25, to: now),
                endDate: calendar.date(byAdding: .day, value: -25, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .inspections,
                description: "Building inspection for insurance claim. Detailed roof and facade assessment.",
                paymentAmount: Decimal(850.00),
                tipAmount: nil,
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -30, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: nil,
                customerRated: true // Already rated
            ),
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: pilot1Id,
                locationLat: 25.7617,
                locationLng: -80.1918,
                locationName: "South Beach, Miami",
                scheduledDate: calendar.date(byAdding: .day, value: -35, to: now),
                endDate: calendar.date(byAdding: .day, value: -35, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .motionPicture,
                description: "Beachfront commercial photography. Lifestyle shots for resort marketing.",
                paymentAmount: Decimal(1300.00),
                tipAmount: Decimal(200.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -40, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: nil,
                customerRated: true // Already rated
            ),
            
            // Cancelled Booking
            Booking(
                id: UUID(),
                customerId: UUID(), // Current customer
                pilotId: nil,
                locationLat: 47.6062,
                locationLng: -122.3321,
                locationName: "Space Needle, Seattle",
                scheduledDate: calendar.date(byAdding: .day, value: -10, to: now),
                endDate: calendar.date(byAdding: .day, value: -10, to: now)?.addingTimeInterval(3600 * 2),
                specialization: .surveillanceSecurity,
                description: "Security surveillance for event. Weather cancellation.",
                paymentAmount: Decimal(700.00),
                tipAmount: nil,
                status: .cancelled,
                createdAt: calendar.date(byAdding: .day, value: -18, to: now) ?? now,
                estimatedFlightHours: 2.0,
                pilotRated: nil,
                customerRated: nil
            )
        ]
    }
    
    // MARK: - Accept Booking (Pilot)
    
    /// Accept a booking. For automotive bookings, this joins the crew instead.
    /// For other bookings, this assigns the pilot directly.
    func acceptBooking(bookingId: UUID, pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get booking details first
            let booking = try await backend.fetchBooking(id: bookingId)
            
            // For automotive bookings, use the crew system
            if booking.isAutomotiveCrewBooking {
                isLoading = false // joinAutomotiveBooking manages its own loading state
                let _ = try await joinAutomotiveBooking(bookingId: bookingId, pilotId: pilotId)
                return
            }
            
            // Non-automotive booking: original single-pilot acceptance logic
            let updateData: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "status": .string(BookingStatus.accepted.rawValue)
            ]
            try await backend.updateBooking(id: bookingId, values: updateData)
            publishBookingChange(for: bookingId)
            
            // Get pilot info for notification
            let pilotProfile = try await backend.fetchUserProfile(userId: pilotId)
            
            // Check customer's notification preferences
            if !skipNetworkCalls {
                do {
                    try await notificationPreferencesService.loadPreferences(userId: booking.customerId)
                    
                    // Send notification to customer if they have booking reminders enabled
                    if notificationPreferencesService.preferences.bookingReminders.system {
                        let aircraftType = booking.specialization?.displayName ?? "drone flight"
                        // Use callsign for customer notifications to maintain pilot privacy
                        let pilotCallsign = pilotProfile.callSign ?? "Pilot"
                        await notificationManager.notifyBookingAccepted(
                            bookingId: bookingId,
                            pilotCallSign: pilotCallsign,
                            aircraftType: aircraftType,
                            departureTime: booking.scheduledDate ?? Date()
                        )
                    }
                    
                    // Schedule 24-hour reminder if there's a scheduled date
                    if let scheduledDate = booking.scheduledDate,
                       notificationPreferencesService.preferences.bookingReminders.system {
                        let aircraftType = booking.specialization?.displayName ?? "drone flight"
                        // Use callsign for customer notifications to maintain pilot privacy
                        let pilotCallsign = pilotProfile.callSign ?? "Pilot"
                        await notificationManager.scheduleBookingReminder(
                            bookingId: bookingId,
                            aircraftType: aircraftType,
                            departureTime: scheduledDate,
                            pilotCallSign: pilotCallsign
                        )
                    }
                } catch {
                    print("Could not load notification preferences: \(error)")
                    // Continue anyway - notification is not critical
                }
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Join Automotive Booking Crew (Pilot)
    
    /// Join an automotive booking crew. For automotive bookings, 4 pilots can join
    /// and the highest-ranked Lieutenant+ becomes the lead.
    func joinAutomotiveBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await backend.joinAutomotiveBooking(bookingId: bookingId, pilotId: pilotId)
            isLoading = false
            
            // If there was an error in the response, throw it
            if let error = response.error, !response.success {
                throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            }

            publishBookingChange(for: bookingId)
            return response
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Join Search & Rescue Booking (Pilot)
    
    /// Join a Search & Rescue mission. Multiple pilots can join.
    /// Payment is calculated after mission completion based on hours worked.
    func joinSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await backend.joinSearchRescueBooking(bookingId: bookingId, pilotId: pilotId)
            isLoading = false
            publishBookingChange(for: bookingId)

            // Notify the beacon creator that a volunteer accepted
            if !skipNetworkCalls {
                Task {
                    let booking = try? await backend.fetchBooking(id: bookingId)
                    let pilotProfile = try? await backend.fetchUserProfile(userId: pilotId)
                    let volunteerCallSign = pilotProfile?.callSign ?? "A volunteer"
                    let missionType = booking?.specialization?.displayName ?? "Search & Rescue"
                    if booking != nil {
                        await notificationManager.notifyBeaconAccepted(
                            bookingId: bookingId,
                            volunteerCallSign: volunteerCallSign,
                            missionType: missionType
                        )
                    }
                }
            }

            return response
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Leave Search & Rescue Booking

    func leaveSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await backend.leaveSearchRescueBooking(bookingId: bookingId, pilotId: pilotId)
            isLoading = false
            publishBookingChange(for: bookingId)
            return response
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func leaveAutomotiveBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        isLoading = true
        errorMessage = nil

        do {
            struct LeaveResult: Codable {
                let success: Bool
                let error: String?
                let message: String?
            }

            let result: LeaveResult = try await supabase
                .rpc("leave_automotive_booking", params: [
                    "p_booking_id": bookingId.uuidString,
                    "p_pilot_id": pilotId.uuidString
                ])
                .execute()
                .value

            isLoading = false

            if !result.success {
                throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: result.error ?? "Failed to leave crew"])
            }

            publishBookingChange(for: bookingId)
            return JoinCrewResponse(
                success: result.success,
                message: result.message,
                crewMember: nil,
                crewStatus: nil,
                error: result.error
            )
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func withdrawFromBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        isLoading = true
        errorMessage = nil

        do {
            struct LeaveResult: Codable {
                let success: Bool
                let error: String?
                let message: String?
            }

            let result: LeaveResult = try await supabase
                .rpc("withdraw_from_booking", params: [
                    "p_booking_id": bookingId.uuidString,
                    "p_pilot_id": pilotId.uuidString
                ])
                .execute()
                .value

            isLoading = false

            if !result.success {
                throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: result.error ?? "Failed to withdraw from booking"])
            }

            publishBookingChange(for: bookingId)
            return JoinCrewResponse(
                success: result.success,
                message: result.message,
                crewMember: nil,
                crewStatus: nil,
                error: result.error
            )
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Fetch Booking Crew

    /// Fetch crew members for a booking. For automotive bookings, returns crew details.
    /// For non-automotive bookings, returns empty crew.
    func fetchBookingCrew(bookingId: UUID, requesterId: UUID?, requesterType: String?) async throws -> BookingCrewResponse {
        do {
            struct CrewRequest: Codable {
                let booking_id: String
                let requester_id: String?
                let requester_type: String?
            }
            
            let request = CrewRequest(
                booking_id: bookingId.uuidString,
                requester_id: requesterId?.uuidString,
                requester_type: requesterType
            )
            
            let response: BookingCrewResponse = try await supabase.functions
                .invoke("get-booking-crew", options: FunctionInvokeOptions(
                    body: request
                ))
            
            return response
        } catch {
            throw error
        }
    }
    
    // MARK: - Fetch Pilot's Crew Memberships
    
    /// Fetch all crew memberships for a pilot (for earnings/balance display)
    func fetchPilotCrewMemberships(pilotId: UUID) async throws -> [BookingCrewMember] {
        do {
            let memberships: [BookingCrewMember] = try await supabase
                .from("booking_crew")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("joined_at", ascending: false)
                .execute()
                .value
            
            return memberships
        } catch {
            throw error
        }
    }
    
    // MARK: - Mark Booking Completion (Mutual Confirmation)
    
    func markBookingCompletion(bookingId: UUID, isPilot: Bool, userId: UUID? = nil) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current booking state
            let booking: Booking = try await supabase
                .from("bookings")
                .select()
                .eq("id", value: bookingId.uuidString)
                .single()
                .execute()
                .value
            
            // Update completion flag
            var updateData: [String: AnyJSON] = [:]
            if isPilot {
                updateData["pilot_completed"] = .bool(true)
            } else {
                updateData["customer_completed"] = .bool(true)
            }
            
            // Check if both parties have completed (after this update)
            // If current user is pilot, check if customer already completed
            // If current user is customer, check if pilot already completed
            let customerCompleted = isPilot ? (booking.customerCompleted == true) : true
            let pilotCompleted = isPilot ? true : (booking.pilotCompleted == true)
            
            // If both have completed, finalize the booking
            if customerCompleted && pilotCompleted {
                updateData["status"] = .string(BookingStatus.completed.rawValue)
                // Set completed_at timestamp when booking is officially completed
                updateData["completed_at"] = .string(ISO8601DateFormatter().string(from: Date()))
                
                // If booking has a charge_id but no transfer_id, trigger transfer
                // Transfer goes directly to Stripe account, balance is managed by Stripe
                if let chargeId = booking.chargeId, booking.transferId == nil, let pilotId = booking.pilotId {
                    // Get payment amount (including tip)
                    let totalAmount = booking.paymentAmount + (booking.tipAmount ?? 0)
                    
                    // Call transfer function
                    struct TransferRequest: Codable {
                        let booking_id: String
                        let amount: Int
                        let currency: String
                        let charge_id: String
                    }
                    
                    struct TransferResponse: Codable {
                        let transferId: String?
                        let isAutomotive: Bool?
                        
                        enum CodingKeys: String, CodingKey {
                            case transferId = "transfer_id"
                            case isAutomotive = "is_automotive"
                        }
                    }
                    
                    let transferRequest = TransferRequest(
                        booking_id: bookingId.uuidString,
                        amount: Int(NSDecimalNumber(decimal: totalAmount * 100).intValue),
                        currency: "usd",
                        charge_id: chargeId
                    )
                    
                    let transferResponse: TransferResponse = try await supabase.functions
                        .invoke("create-transfer", options: FunctionInvokeOptions(
                            body: transferRequest
                        ))
                    
                    // Update booking with transfer_id (for non-automotive bookings)
                    // For automotive bookings, transfer_id is updated by the edge function
                    if let transferId = transferResponse.transferId {
                        updateData["transfer_id"] = .string(transferId)
                    }
                    
                    // Note: Balance is managed by Stripe, no need to update database balance
                    // The transfer adds funds to the pilot's Stripe account balance
                }
            }
            
            try await supabase
                .from("bookings")
                .update(updateData)
                .eq("id", value: bookingId.uuidString)
                .execute()
            publishBookingChange(for: bookingId)
            
            // Handle automotive booking completion tasks
            let isCompleted = customerCompleted && pilotCompleted
            if isCompleted && booking.isAutomotiveCrewBooking {
                // Fetch crew members for notifications and stats updates
                do {
                    let crewMemberships: [BookingCrewMember] = try await supabase
                        .from("booking_crew")
                        .select()
                        .eq("booking_id", value: bookingId.uuidString)
                        .execute()
                        .value
                    
                    // Send completion notification to current pilot (if pilot is completing)
                    if isPilot, let currentUserId = userId,
                       let myMembership = crewMemberships.first(where: { $0.pilotId == currentUserId }) {
                        await NotificationManager.shared.notifyCrewBookingCompleted(
                            bookingId: bookingId,
                            payoutAmount: myMembership.payoutAmount,
                            role: myMembership.role.rawValue
                        )
                    }
                    
                    // Update pilot stats for ALL crew members
                    if let hours = booking.estimatedFlightHours {
                        let rankingService = RankingService()
                        for member in crewMemberships {
                            do {
                                try await rankingService.updateFlightHours(
                                    pilotId: member.pilotId,
                                    additionalHours: hours
                                )
                                print("✅ Updated stats for crew member: \(member.pilotId)")
                            } catch {
                                // Log but don't fail the whole operation if one pilot's stats fail
                                print("⚠️ Error updating stats for crew member \(member.pilotId): \(error)")
                            }
                        }
                    }
                } catch {
                    print("Error fetching crew for completion tasks: \(error)")
                    // Don't throw - these tasks are not critical to booking completion
                }
            }
            
            isLoading = false
            return isCompleted
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Add Tip and Update Balance
    
    func addTipAndUpdateBalance(bookingId: UUID, tipAmount: Decimal) async throws {
        throw NSError(
            domain: "BookingService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unsafe tip flow disabled. Use recordPaidTip after a successful payment instead."]
        )
    }

    // MARK: - Search & Rescue Completion Methods
    
    /// Update the final hours worked for a Search & Rescue booking
    func updateSearchRescueHours(bookingId: UUID, hoursWorked: Double) async throws {
        let updateData: [String: AnyJSON] = [
            "final_hours_worked": .double(hoursWorked)
        ]
        
        try await supabase
            .from("bookings")
            .update(updateData)
            .eq("id", value: bookingId.uuidString)
            .execute()
    }
    
    /// Complete a Search & Rescue mission with payment
    /// This is called after the customer has paid for the mission
    func completeSearchRescuePayment(
        bookingId: UUID,
        paymentIntentId: String,
        totalAmount: Decimal,
        hoursWorked: Double,
        pilotCount: Int
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get charge ID from payment intent
            let chargeId = try await getChargeIdFromPaymentIntent(paymentIntentId: paymentIntentId)
            
            // Update booking with payment info and mark as completed
            let updateData: [String: AnyJSON] = [
                "status": .string(BookingStatus.completed.rawValue),
                "completed_at": .string(ISO8601DateFormatter().string(from: Date())),
                "customer_completed": .bool(true),
                "pilot_completed": .bool(true),
                "final_hours_worked": .double(hoursWorked),
                "payment_amount": .double(NSDecimalNumber(decimal: totalAmount).doubleValue),
                "payment_intent_id": .string(paymentIntentId),
                "charge_id": .string(chargeId)
            ]
            
            try await backend.updateBooking(id: bookingId, values: updateData)

            // Trigger transfer to pilots
            struct TransferRequest: Codable {
                let booking_id: String
                let amount: Int
                let currency: String
                let charge_id: String
            }
            
            let transferRequest = TransferRequest(
                booking_id: bookingId.uuidString,
                amount: Int(NSDecimalNumber(decimal: totalAmount * 100).intValue),
                currency: "usd",
                charge_id: chargeId
            )
            
            // Trigger transfer to pilots (we don't need to capture the response)
            try await supabase.functions
                .invoke("create-transfer", options: FunctionInvokeOptions(
                    body: transferRequest
                ))
            
            // Update flight hours for all participating pilots
            let crewMemberships = try await backend.fetchBookingCrew(bookingId: bookingId)

            let rankingService = RankingService()
            for crewMember in crewMemberships {
                try? await rankingService.updateFlightHours(pilotId: crewMember.pilotId, additionalHours: hoursWorked)
            }

            // Notify crew about mission completion and payout
            if !skipNetworkCalls {
                let perPilotPayout = pilotCount > 0 ? totalAmount / Decimal(pilotCount) : totalAmount
                let missionType = (try? await backend.fetchBooking(id: bookingId))?.specialization?.displayName ?? "Search & Rescue"
                Task {
                    await notificationManager.notifyBeaconResolved(bookingId: bookingId, missionType: missionType)
                    for crewMember in crewMemberships {
                        await notificationManager.notifyPayoutConfirmation(bookingId: bookingId, payoutAmount: perPilotPayout)
                    }
                }
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Complete a voluntary Search & Rescue mission (no payment)
    func completeVoluntaryMission(bookingId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let updateData: [String: AnyJSON] = [
                "status": .string(BookingStatus.completed.rawValue),
                "completed_at": .string(ISO8601DateFormatter().string(from: Date())),
                "customer_completed": .bool(true),
                "pilot_completed": .bool(true)
            ]
            
            try await backend.updateBooking(id: bookingId, values: updateData)

            // Update flight hours for all participating pilots
            let booking = try await backend.fetchBooking(id: bookingId)

            let crewMemberships = try await backend.fetchBookingCrew(bookingId: bookingId)
            
            let hoursWorked = booking.finalHoursWorked ?? booking.estimatedFlightHours ?? 0
            let rankingService = RankingService()
            for crewMember in crewMemberships {
                try? await rankingService.updateFlightHours(pilotId: crewMember.pilotId, additionalHours: hoursWorked)
            }

            // Notify crew about voluntary mission completion
            if !skipNetworkCalls {
                let missionType = booking.specialization?.displayName ?? "Search & Rescue"
                Task {
                    await notificationManager.notifyBeaconResolved(bookingId: bookingId, missionType: missionType)
                }
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Helper to get charge ID from a payment intent
    private func getChargeIdFromPaymentIntent(paymentIntentId: String) async throws -> String {
        // The charge ID is typically stored in the payment intent response
        // For now, we'll use the backend to retrieve it
        struct ChargeRequest: Codable {
            let payment_intent_id: String
        }
        
        struct ChargeResponse: Codable {
            let chargeId: String?
            
            enum CodingKeys: String, CodingKey {
                case chargeId = "charge_id"
            }
        }
        
        let request = ChargeRequest(payment_intent_id: paymentIntentId)
        
        let response: ChargeResponse = try await supabase.functions
            .invoke("get-charge-id", options: FunctionInvokeOptions(
                body: request
            ))
        
        guard let chargeId = response.chargeId else {
            throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not retrieve charge ID"])
        }
        
        return chargeId
    }
    
    // MARK: - Complete Booking (Legacy - kept for backward compatibility)
    
    func completeBooking(bookingId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // First, get the booking to check if it has a charge_id
            let booking: Booking = try await supabase
                .from("bookings")
                .select()
                .eq("id", value: bookingId.uuidString)
                .single()
                .execute()
                .value
            
            // Update status to completed
            var updateData: [String: AnyJSON] = ["status": .string(BookingStatus.completed.rawValue)]
            
            // If booking has a charge_id but no transfer_id, trigger transfer
            if let chargeId = booking.chargeId, booking.transferId == nil, booking.pilotId != nil {
                // Get payment amount (including tip)
                let totalAmount = booking.paymentAmount + (booking.tipAmount ?? 0)
                
                // Call transfer function
                struct TransferRequest: Codable {
                    let booking_id: String
                    let amount: Int
                    let currency: String
                    let charge_id: String
                }
                
                struct TransferResponse: Codable {
                    let transferId: String?
                    let isAutomotive: Bool?
                    
                    enum CodingKeys: String, CodingKey {
                        case transferId = "transfer_id"
                        case isAutomotive = "is_automotive"
                    }
                }
                
                let transferRequest = TransferRequest(
                    booking_id: bookingId.uuidString,
                    amount: Int(NSDecimalNumber(decimal: totalAmount * 100).intValue),
                    currency: "usd",
                    charge_id: chargeId
                )
                
                let transferResponse: TransferResponse = try await supabase.functions
                    .invoke("create-transfer", options: FunctionInvokeOptions(
                        body: transferRequest
                    ))
                
                // Update booking with transfer_id (for non-automotive bookings)
                if let transferId = transferResponse.transferId {
                    updateData["transfer_id"] = .string(transferId)
                }
            }
            
            try await supabase
                .from("bookings")
                .update(updateData)
                .eq("id", value: bookingId.uuidString)
                .execute()
            publishBookingChange(for: bookingId)

            // Notify pilot about payout
            if !skipNetworkCalls, let pilotId = booking.pilotId, booking.chargeId != nil {
                let totalAmount = booking.paymentAmount + (booking.tipAmount ?? 0)
                Task {
                    await notificationManager.notifyPayoutConfirmation(bookingId: bookingId, payoutAmount: totalAmount)
                }
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Add Tip to Booking
    
    func addTip(bookingId: UUID, tipAmount: Decimal) async throws {
        throw NSError(
            domain: "BookingService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unsafe tip flow disabled. Use recordPaidTip after a successful payment instead."]
        )
    }

    // MARK: - Record Paid Tip

    func recordPaidTip(
        bookingId: UUID,
        tipAmount: Decimal,
        paymentIntentId: String,
        chargeId: String
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let booking: Booking = try await supabase
                .from("bookings")
                .select()
                .eq("id", value: bookingId.uuidString)
                .single()
                .execute()
                .value

            guard booking.status == .completed else {
                throw NSError(
                    domain: "BookingService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Tips can only be added after the booking is completed."]
                )
            }

            if booking.specialization == .automotive || booking.specialization == .searchRescue {
                throw NSError(
                    domain: "BookingService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Tips are only supported for single-pilot bookings."]
                )
            }

            if booking.tipPaymentIntentId != nil {
                throw NSError(
                    domain: "BookingService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "A tip has already been recorded for this booking."]
                )
            }

            let updateData: [String: AnyJSON] = [
                "tip_amount": .double(NSDecimalNumber(decimal: tipAmount).doubleValue),
                "tip_payment_intent_id": .string(paymentIntentId),
                "tip_charge_id": .string(chargeId)
            ]
            do {
                let _: Booking = try await supabase
                    .from("bookings")
                    .update(updateData)
                    .eq("id", value: bookingId.uuidString)
                    .is("tip_payment_intent_id", value: nil)
                    .select()
                    .single()
                    .execute()
                    .value
            } catch {
                if let latestBooking = try? await getBooking(bookingId: bookingId),
                   latestBooking.tipPaymentIntentId != nil {
                    throw NSError(
                        domain: "BookingService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "A tip has already been recorded for this booking."]
                    )
                }
                throw error
            }
            publishBookingChange(for: bookingId)

            if booking.pilotId != nil {
                struct TipTransferRequest: Codable {
                    let booking_id: String
                    let charge_id: String
                    let currency: String
                    let transfer_type: String
                }

                do {
                    let request = TipTransferRequest(
                        booking_id: bookingId.uuidString,
                        charge_id: chargeId,
                        currency: "usd",
                        transfer_type: "tip"
                    )

                    let _: TransferResponse = try await supabase.functions
                        .invoke("create-transfer", options: FunctionInvokeOptions(body: request))
                } catch {
                    // The customer has already paid and the tip is recorded in the DB
                    // (tip_payment_intent_id / tip_charge_id). The transfer to the pilot
                    // failed and will need manual reconciliation or a retry job
                    // (tip_charge_id IS NOT NULL AND tip_transfer_id IS NULL).
                    print("[WARNING] Tip transfer failed for booking \(bookingId). Tip is recorded but payout is pending: \(error)")
                    errorMessage = "Tip paid successfully but the payout to the pilot is pending. It will be processed shortly."
                }

                if !skipNetworkCalls {
                    Task {
                        let customerProfile = try? await backend.fetchUserProfile(userId: booking.customerId)
                        let customerName = customerProfile?.callSign ?? "Customer"
                        await notificationManager.notifyTipReceived(
                            bookingId: bookingId,
                            tipAmount: tipAmount,
                            customerName: customerName
                        )
                    }
                }
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Mark Rating Status
    
    func markRatingStatus(bookingId: UUID, isPilot: Bool, hasRated: Bool) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let updateData: [String: AnyJSON] = [
                isPilot ? "pilot_rated" : "customer_rated": .bool(hasRated)
            ]
            try await supabase
                .from("bookings")
                .update(updateData)
                .eq("id", value: bookingId.uuidString)
                .execute()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Get Completed Bookings Count
    
    func getCompletedBookingsCount(userId: UUID, isPilot: Bool) async throws -> Int {
        do {
            let query = supabase
                .from("bookings")
                .select("id", count: .exact)
                .eq("status", value: BookingStatus.completed.rawValue)
            
            let result: Int
            if isPilot {
                result = try await query
                    .eq("pilot_id", value: userId.uuidString)
                    .execute()
                    .count ?? 0
            } else {
                result = try await query
                    .eq("customer_id", value: userId.uuidString)
                    .execute()
                    .count ?? 0
            }
            
            return result
        } catch {
            throw error
        }
    }
    
    // MARK: - Get Revenue Data for Pilot
    
    func getPilotRevenue(pilotId: UUID) async throws -> [Booking] {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // Simulate API call delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // SAMPLE DATA FOR DEMO PURPOSES
            let sampleCompletedBookings = createSampleRevenueBookings()
            return sampleCompletedBookings
        }
        
        // Real backend call
        do {
            let bookings: [Booking] = try await supabase
                .from("bookings")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .eq("status", value: BookingStatus.completed.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return bookings
        } catch {
            throw error
        }
    }
    
    // MARK: - Sample Data for Demo (Revenue/Completed Bookings)
    // TODO: Remove this function when connecting to real backend
    
    private func createSampleRevenueBookings() -> [Booking] {
        let calendar = Calendar.current
        let now = Date()
        
        // Generate bookings across multiple months for demo chart
        return [
            // Current Month
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(),
                locationLat: 40.7580,
                locationLng: -73.9855,
                locationName: "Central Park, New York",
                scheduledDate: calendar.date(byAdding: .day, value: -5, to: now),
                endDate: calendar.date(byAdding: .day, value: -5, to: now)?.addingTimeInterval(3600 * 4),
                specialization: .realEstate,
                description: "Event coverage for outdoor festival.",
                paymentAmount: Decimal(850.00),
                tipAmount: Decimal(100.00),
                status: .completed,
                createdAt: now,
                estimatedFlightHours: 4.0,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(),
                locationLat: 41.8781,
                locationLng: -87.6298,
                locationName: "Navy Pier, Chicago",
                scheduledDate: calendar.date(byAdding: .day, value: -8, to: now),
                endDate: calendar.date(byAdding: .day, value: -8, to: now)?.addingTimeInterval(3600 * 2),
                specialization: .realEstate,
                description: "Aerial shots for property development.",
                paymentAmount: Decimal(950.00),
                tipAmount: Decimal(50.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                estimatedFlightHours: 2.0,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            // Previous Month
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(),
                locationLat: 25.7617,
                locationLng: -80.1918,
                locationName: "South Beach, Miami",
                scheduledDate: calendar.date(byAdding: .day, value: -35, to: now),
                endDate: calendar.date(byAdding: .day, value: -35, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .motionPicture,
                description: "Beachfront cinematography for commercial.",
                paymentAmount: Decimal(1400.00),
                tipAmount: Decimal(200.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -40, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(),
                locationLat: 47.6062,
                locationLng: -122.3321,
                locationName: "Space Needle, Seattle",
                scheduledDate: calendar.date(byAdding: .day, value: -45, to: now),
                endDate: calendar.date(byAdding: .day, value: -45, to: now)?.addingTimeInterval(3600 * 2),
                specialization: .inspections,
                description: "Rooftop inspection for building maintenance.",
                paymentAmount: Decimal(1100.00),
                tipAmount: nil,
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -50, to: now) ?? now,
                estimatedFlightHours: 2.0,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(),
                locationLat: 39.9526,
                locationLng: -75.1652,
                locationName: "Independence Hall, Philadelphia",
                scheduledDate: calendar.date(byAdding: .day, value: -55, to: now),
                endDate: calendar.date(byAdding: .day, value: -55, to: now)?.addingTimeInterval(3600 * 4),
                specialization: .inspections,
                description: "3D mapping for historical site documentation.",
                paymentAmount: Decimal(1800.00),
                tipAmount: Decimal(150.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -60, to: now) ?? now,
                estimatedFlightHours: 4.5,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            // Two Months Ago
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(),
                locationLat: 37.7749,
                locationLng: -122.4194,
                locationName: "Golden Gate Bridge, San Francisco",
                scheduledDate: calendar.date(byAdding: .day, value: -70, to: now),
                endDate: calendar.date(byAdding: .day, value: -70, to: now)?.addingTimeInterval(3600 * 3),
                specialization: .realEstate,
                description: "Real estate photography for luxury property.",
                paymentAmount: Decimal(1200.00),
                tipAmount: Decimal(100.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -75, to: now) ?? now,
                estimatedFlightHours: 3.0,
                pilotRated: true,
                customerRated: true,
                requiredMinimumRank: 0
            ),
            Booking(
                id: UUID(),
                customerId: UUID(),
                pilotId: UUID(),
                locationLat: 34.0522,
                locationLng: -118.2437,
                locationName: "Griffith Observatory, Los Angeles",
                scheduledDate: calendar.date(byAdding: .day, value: -80, to: now),
                endDate: calendar.date(byAdding: .day, value: -80, to: now)?.addingTimeInterval(3600 * 5),
                specialization: .motionPicture,
                description: "Cinematic B-roll footage for documentary.",
                paymentAmount: Decimal(1300.00),
                tipAmount: Decimal(200.00),
                status: .completed,
                createdAt: calendar.date(byAdding: .day, value: -85, to: now) ?? now,
                estimatedFlightHours: 5.0,
                pilotRated: true,
                customerRated: true
            )
        ]
    }
    
    // MARK: - Start Booking In Progress

    /// Transitions a booking from accepted/staffed → in_progress.
    /// Called when the pilot begins the job.
    func startBookingInProgress(bookingId: UUID) async throws {
        isLoading = true
        errorMessage = nil

        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
            return
        }

        do {
            // Get current booking state
            let booking: Booking = try await supabase
                .from("bookings")
                .select()
                .eq("id", value: bookingId.uuidString)
                .single()
                .execute()
                .value

            // Validate state transition: only accepted or staffed → in_progress
            guard booking.status == .accepted || booking.status == .staffed else {
                isLoading = false
                throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Booking must be in accepted or staffed status to start. Current status: \(booking.status.displayName)"])
            }

            let updateData: [String: AnyJSON] = [
                "status": .string(BookingStatus.inProgress.rawValue)
            ]

            try await supabase
                .from("bookings")
                .update(updateData)
                .eq("id", value: bookingId.uuidString)
                .execute()

            // Notify customer that their job has started
            if !skipNetworkCalls {
                Task {
                    let aircraftType = booking.specialization?.displayName ?? "drone flight"
                    await NotificationManager.shared.sendRemotePushNotification(
                        recipientUserId: booking.customerId,
                        title: "Job Started!",
                        body: "Your \(aircraftType) booking at \(booking.locationName) is now in progress.",
                        data: [
                            "bookingId": bookingId.uuidString,
                            "type": "booking_in_progress"
                        ]
                    )
                }
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Mark Search & Rescue as Staffed

    /// Transitions a Search & Rescue booking from available → staffed
    /// when enough pilots have joined (meets numberOfPilots threshold).
    func markSearchRescueAsStaffed(bookingId: UUID) async throws {
        isLoading = true
        errorMessage = nil

        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
            return
        }

        do {
            // Get current booking state
            let booking = try await backend.fetchBooking(id: bookingId)

            // Validate: must be S&R and available
            guard booking.isSearchRescueCrewBooking else {
                isLoading = false
                throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only Search & Rescue bookings can be marked as staffed"])
            }

            guard booking.status == .available else {
                isLoading = false
                throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Booking must be available to mark as staffed. Current status: \(booking.status.displayName)"])
            }

            // Verify enough pilots have joined
            let crewMembers = try await backend.fetchBookingCrew(bookingId: bookingId)

            let requiredPilots = booking.numberOfPilots ?? 1
            guard crewMembers.count >= requiredPilots else {
                isLoading = false
                throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not enough pilots (\(crewMembers.count)/\(requiredPilots)) to mark as staffed"])
            }

            let updateData: [String: AnyJSON] = [
                "status": .string(BookingStatus.staffed.rawValue)
            ]

            try await backend.updateBooking(id: bookingId, values: updateData)

            // Notify customer that their S&R mission is staffed
            if !skipNetworkCalls {
                Task {
                    await NotificationManager.shared.sendRemotePushNotification(
                        recipientUserId: booking.customerId,
                        title: "Mission Staffed",
                        body: "Your Search & Rescue mission has enough pilots and is ready to begin.",
                        data: [
                            "bookingId": bookingId.uuidString,
                            "type": "booking_staffed"
                        ]
                    )
                }
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Expiration Logic

    /// Check for and expire bookings that have passed their expires_at date.
    /// Queries bookings where status = 'available' AND expires_at < now().
    func checkAndExpireBookings() async throws {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            return
        }

        do {
            let now = ISO8601DateFormatter().string(from: Date())

            // Fetch available bookings that have expired
            let expiredBookings: [Booking] = try await supabase
                .from("bookings")
                .select()
                .eq("status", value: BookingStatus.available.rawValue)
                .not("expires_at", operator: .is, value: "null")
                .lte("expires_at", value: now)
                .execute()
                .value

            // Update each expired booking
            for booking in expiredBookings {
                try await supabase
                    .from("bookings")
                    .update(["status": AnyJSON.string(BookingStatus.expired.rawValue)])
                    .eq("id", value: booking.id.uuidString)
                    .execute()

                print("Expired booking \(booking.id)")
            }
        } catch {
            print("Error checking for expired bookings: \(error)")
            throw error
        }
    }

    /// Notify customers whose bookings are expiring within 24 hours.
    /// Only notifies bookings where expiration_notified = false.
    func notifyExpiringBookings() async throws {
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            return
        }

        do {
            let now = Date()
            let in24Hours = ISO8601DateFormatter().string(from: now.addingTimeInterval(24 * 60 * 60))
            let nowString = ISO8601DateFormatter().string(from: now)

            // Fetch bookings expiring within 24 hours that haven't been notified
            let expiringBookings: [Booking] = try await supabase
                .from("bookings")
                .select()
                .eq("status", value: BookingStatus.available.rawValue)
                .eq("expiration_notified", value: false)
                .not("expires_at", operator: .is, value: "null")
                .gt("expires_at", value: nowString)
                .lte("expires_at", value: in24Hours)
                .execute()
                .value

            for booking in expiringBookings {
                // Send push notification to customer
                if !skipNetworkCalls {
                    await NotificationManager.shared.sendRemotePushNotification(
                        recipientUserId: booking.customerId,
                        title: "Booking Expiring Soon",
                        body: "Your booking for \(booking.locationName) is expiring soon. Update the date to keep it active.",
                        data: [
                            "bookingId": booking.id.uuidString,
                            "type": "booking_expiring"
                        ]
                    )
                }

                // Mark as notified
                try await supabase
                    .from("bookings")
                    .update(["expiration_notified": AnyJSON.bool(true)])
                    .eq("id", value: booking.id.uuidString)
                    .execute()
            }
        } catch {
            print("Error notifying about expiring bookings: \(error)")
            throw error
        }
    }

    /// Extend a booking by updating its scheduled date and resetting expiration.
    /// Only works if the booking is still available (not yet accepted or expired).
    func extendBooking(bookingId: UUID, newScheduledDate: Date, newEndDate: Date?) async throws {
        isLoading = true
        errorMessage = nil

        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
            return
        }

        do {
            // Verify booking is still available
            let booking: Booking = try await supabase
                .from("bookings")
                .select()
                .eq("id", value: bookingId.uuidString)
                .single()
                .execute()
                .value

            guard booking.status == .available else {
                isLoading = false
                throw NSError(domain: "BookingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Can only extend bookings that are still available. Current status: \(booking.status.displayName)"])
            }

            var updateData: [String: AnyJSON] = [
                "scheduled_date": .string(ISO8601DateFormatter().string(from: newScheduledDate)),
                "expires_at": .string(ISO8601DateFormatter().string(from: newScheduledDate)),
                "expiration_notified": .bool(false)
            ]

            if let newEndDate = newEndDate {
                updateData["end_date"] = .string(ISO8601DateFormatter().string(from: newEndDate))
            }

            try await supabase
                .from("bookings")
                .update(updateData)
                .eq("id", value: bookingId.uuidString)
                .execute()

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Cancel Booking

    func cancelBooking(bookingId: UUID) async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch booking details before cancelling (for notification context)
            let booking: Booking = try await supabase
                .from("bookings")
                .select()
                .eq("id", value: bookingId.uuidString)
                .single()
                .execute()
                .value

            let updateData: [String: AnyJSON] = ["status": .string(BookingStatus.cancelled.rawValue)]
            try await supabase
                .from("bookings")
                .update(updateData)
                .eq("id", value: bookingId.uuidString)
                .execute()

            // Cancel any pending booking reminders
            NotificationManager.shared.cancelBookingReminder(bookingId: bookingId)

            // Notify the other party about the cancellation
            if !skipNetworkCalls, let pilotId = booking.pilotId {
                let aircraftType = booking.specialization?.displayName ?? "booking"

                // Notify pilot that customer cancelled
                Task {
                    let customerProfile = try? await backend.fetchUserProfile(userId: booking.customerId)
                    let customerName = customerProfile?.callSign ?? "Customer"
                    await notificationManager.notifyBookingCancelled(
                        bookingId: bookingId,
                        cancelledByName: customerName,
                        aircraftType: aircraftType
                    )
                }
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Get Single Booking
    
    func getBooking(bookingId: UUID) async throws -> Booking {
        let booking: Booking = try await supabase
            .from("bookings")
            .select()
            .eq("id", value: bookingId.uuidString)
            .single()
            .execute()
            .value
        
        return booking
    }
    
    // MARK: - Notification Helpers
    
    /// Notify pilots about a new available booking using geofencing
    /// Uses last known pilot location (transponder) and a default search radius to filter recipients.
    private func notifyNearbyPilotsAboutNewBooking(booking: Booking) async {
        do {
            // Preload latest pilot locations to avoid N+1 lookups
            let pilotLocations = try await fetchLatestPilotLocations()
            
            // Fetch all pilots
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("user_type", value: "pilot")
                .execute()
                .value
            
            // Notify each pilot who has booking update notifications enabled
            for profile in profiles {
                // Skip if this is the customer who created the booking
                if profile.id == booking.customerId {
                    continue
                }
                
                // Require a recent location for geofencing
                guard let locationSnapshot = pilotLocations[profile.id],
                      let pilotLat = locationSnapshot.lastLocationLat,
                      let pilotLng = locationSnapshot.lastLocationLng else {
                    continue
                }
                
                let bookingLocation = CLLocation(latitude: booking.locationLat, longitude: booking.locationLng)
                let pilotLocation = CLLocation(latitude: pilotLat, longitude: pilotLng)
                
                // Compute distance and filter by pilot radius (fallback to default if none saved)
                let distanceMeters = bookingLocation.distance(from: pilotLocation)
                let searchRadiusMeters = defaultPilotSearchRadiusMiles * metersPerMile
                
                // Skip pilots outside their search radius
                guard distanceMeters <= searchRadiusMeters else { continue }
                
                let distanceMiles = distanceMeters / metersPerMile
                
                // Load pilot's notification preferences
                do {
                    try await notificationPreferencesService.loadPreferences(userId: profile.id)
                    
                    // Check if pilot has booking update notifications enabled
                    if notificationPreferencesService.preferences.bookingUpdates.system {
                        let aircraftType = booking.specialization?.displayName ?? "Drone flight"
                        
                        await notificationManager.notifyNearbyBooking(
                            bookingId: booking.id,
                            aircraftType: aircraftType,
                            distance: distanceMiles,
                            departureTime: booking.scheduledDate ?? Date()
                        )
                    }
                } catch {
                    print("Could not load notification preferences for pilot \(profile.id): \(error)")
                    // Continue to next pilot
                }
            }
        } catch {
            print("Error notifying pilots about new booking: \(error)")
            // Non-critical error, don't throw
        }
    }
    
    /// Fetch the most recent location for each pilot from transponder records
    private func fetchLatestPilotLocations() async throws -> [UUID: PilotLocationSnapshot] {
        let records: [PilotLocationSnapshot] = try await supabase
            .from("transponders")
            .select("pilot_id,last_location_lat,last_location_lng,last_location_update,is_location_tracking_enabled")
            .execute()
            .value
        
        var latestByPilot: [UUID: PilotLocationSnapshot] = [:]
        
        for record in records {
            // Skip if tracking disabled or location missing
            guard record.isLocationTrackingEnabled ?? true,
                  record.lastLocationLat != nil,
                  record.lastLocationLng != nil else {
                continue
            }
            
            if let existing = latestByPilot[record.pilotId] {
                // Keep the most recent update per pilot
                if (record.lastLocationUpdate ?? .distantPast) > (existing.lastLocationUpdate ?? .distantPast) {
                    latestByPilot[record.pilotId] = record
                }
            } else {
                latestByPilot[record.pilotId] = record
            }
        }
        
        return latestByPilot
    }
}

// MARK: - Supporting Models

private struct PilotLocationSnapshot: Decodable {
    let pilotId: UUID
    let lastLocationLat: Double?
    let lastLocationLng: Double?
    let lastLocationUpdate: Date?
    let isLocationTrackingEnabled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case pilotId = "pilot_id"
        case lastLocationLat = "last_location_lat"
        case lastLocationLng = "last_location_lng"
        case lastLocationUpdate = "last_location_update"
        case isLocationTrackingEnabled = "is_location_tracking_enabled"
    }
}

// MARK: - Default Backend & Protocol Conformances

private struct SupabaseBookingBackend: BookingBackend {
    private let client = SupabaseClient.shared.client
    
    func createBooking(payload: [String: AnyJSON], bookingId: UUID) async throws -> Booking {
        try await client
            .from("bookings")
            .insert(payload)
            .execute()
        
        return try await fetchBooking(id: bookingId)
    }
    
    func fetchBooking(id: UUID) async throws -> Booking {
        try await client
            .from("bookings")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }
    
    func updateBooking(id: UUID, values: [String: AnyJSON]) async throws {
        try await client
            .from("bookings")
            .update(values)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func joinAutomotiveBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        struct JoinRequest: Codable {
            let booking_id: String
            let pilot_id: String
        }
        
        let request = JoinRequest(booking_id: bookingId.uuidString, pilot_id: pilotId.uuidString)
        
        return try await client.functions
            .invoke("join-automotive-booking", options: FunctionInvokeOptions(body: request))
    }
    
    func fetchUserProfile(userId: UUID) async throws -> UserProfile {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    func joinSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        struct JoinResult: Codable {
            let success: Bool
            let error: String?
            let message: String?
        }
        let result: JoinResult = try await client
            .rpc("join_search_rescue_booking", params: [
                "p_booking_id": bookingId.uuidString,
                "p_pilot_id": pilotId.uuidString
            ])
            .execute()
            .value
        if !result.success {
            throw NSError(domain: "BookingService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: result.error ?? "Failed to join mission"])
        }
        return JoinCrewResponse(success: result.success, message: result.message,
                                crewMember: nil, crewStatus: nil, error: result.error)
    }

    func leaveSearchRescueBooking(bookingId: UUID, pilotId: UUID) async throws -> JoinCrewResponse {
        struct LeaveResult: Codable {
            let success: Bool
            let error: String?
            let message: String?
        }
        let result: LeaveResult = try await client
            .rpc("leave_search_rescue_booking", params: [
                "p_booking_id": bookingId.uuidString,
                "p_pilot_id": pilotId.uuidString
            ])
            .execute()
            .value
        if !result.success {
            throw NSError(domain: "BookingService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: result.error ?? "Failed to leave mission"])
        }
        return JoinCrewResponse(success: result.success, message: result.message,
                                crewMember: nil, crewStatus: nil, error: result.error)
    }

    func fetchBookingCrew(bookingId: UUID) async throws -> [BookingCrewMember] {
        try await client
            .from("booking_crew")
            .select()
            .eq("booking_id", value: bookingId.uuidString)
            .execute()
            .value
    }
}

extension NotificationManager: BookingNotificationManaging {}

extension NotificationPreferencesService: NotificationPreferencesProviding {}
