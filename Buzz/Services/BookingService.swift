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

@MainActor
class BookingService: ObservableObject {
    @Published var availableBookings: [Booking] = []
    @Published var myBookings: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Create Booking (Customer)
    
    func createBooking(
        customerId: UUID,
        location: CLLocationCoordinate2D,
        locationName: String,
        scheduledDate: Date?,
        endDate: Date? = nil,
        specialization: BookingSpecialization?,
        description: String,
        paymentAmount: Decimal,
        estimatedFlightHours: Double
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            var booking: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "customer_id": .string(customerId.uuidString),
                "location_lat": .double(location.latitude),
                "location_lng": .double(location.longitude),
                "location_name": .string(locationName),
                "description": .string(description),
                "payment_amount": .double(NSDecimalNumber(decimal: paymentAmount).doubleValue),
                "status": .string(BookingStatus.available.rawValue),
                "created_at": .string(ISO8601DateFormatter().string(from: Date())),
                "estimated_flight_hours": .double(estimatedFlightHours)
            ]
            
            if let scheduledDate = scheduledDate {
                booking["scheduled_date"] = .string(ISO8601DateFormatter().string(from: scheduledDate))
            }
            
            if let endDate = endDate {
                booking["end_date"] = .string(ISO8601DateFormatter().string(from: endDate))
            }
            
            if let specialization = specialization {
                booking["specialization"] = .string(specialization.rawValue)
            }
            
            try await supabase
                .from("bookings")
                .insert(booking)
                .execute()
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Fetch Available Bookings (Pilot)
    
    func fetchAvailableBookings() async throws {
        isLoading = true
        errorMessage = nil
        
        // TODO: DEMO MODE - Replace this sample data with real backend call
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // SAMPLE DATA FOR DEMO PURPOSES - Replace with real Supabase query when ready
        let sampleBookings = createSampleAvailableBookings()
        
        await MainActor.run {
            self.availableBookings = sampleBookings
            self.isLoading = false
        }
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            let bookings: [Booking] = try await supabase
                .from("bookings")
                .select()
                .eq("status", value: BookingStatus.available.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            
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
        */
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
                customerRated: nil
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
                customerRated: nil
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
                customerRated: nil
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
                customerRated: nil
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
                customerRated: nil
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
            )
        ]
    }
    
    // MARK: - Fetch My Bookings
    
    func fetchMyBookings(userId: UUID, isPilot: Bool) async throws {
        isLoading = true
        errorMessage = nil
        
        // TODO: DEMO MODE - Replace this sample data with real backend call
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // SAMPLE DATA FOR DEMO PURPOSES - Replace with real Supabase query when ready
        let sampleBookings = isPilot ? createSamplePilotBookings() : createSampleCustomerBookings()
        
        await MainActor.run {
            self.myBookings = sampleBookings
            self.isLoading = false
        }
        
        return
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            let query = supabase
                .from("bookings")
                .select()
            
            let result: [Booking]
            if isPilot {
                result = try await query
                    .eq("pilot_id", value: userId.uuidString)
                    .in("status", values: [BookingStatus.accepted.rawValue, BookingStatus.completed.rawValue])
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            } else {
                result = try await query
                    .eq("customer_id", value: userId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }
            
            await MainActor.run {
                self.myBookings = result
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
        */
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
                customerRated: nil
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
                customerRated: nil
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
                customerRated: true
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
                customerRated: true
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
                customerRated: true
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
        // For customer view, return empty or minimal sample data
        // In production, this would fetch customer's own bookings
        return []
    }
    
    // MARK: - Accept Booking (Pilot)
    
    func acceptBooking(bookingId: UUID, pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let updateData: [String: AnyJSON] = [
                "pilot_id": .string(pilotId.uuidString),
                "status": .string(BookingStatus.accepted.rawValue)
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
    
    // MARK: - Complete Booking
    
    func completeBooking(bookingId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let updateData: [String: AnyJSON] = ["status": .string(BookingStatus.completed.rawValue)]
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
    
    // MARK: - Add Tip to Booking
    
    func addTip(bookingId: UUID, tipAmount: Decimal) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let updateData: [String: AnyJSON] = [
                "tip_amount": .double(NSDecimalNumber(decimal: tipAmount).doubleValue)
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
        // TODO: DEMO MODE - Replace this sample data with real backend call
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // SAMPLE DATA FOR DEMO PURPOSES - Replace with real Supabase query when ready
        let sampleCompletedBookings = createSampleRevenueBookings()
        return sampleCompletedBookings
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
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
        */
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
                customerRated: true
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
                customerRated: true
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
                customerRated: true
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
                customerRated: true
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
                customerRated: true
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
                customerRated: true
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
    
    // MARK: - Cancel Booking
    
    func cancelBooking(bookingId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let updateData: [String: AnyJSON] = ["status": .string(BookingStatus.cancelled.rawValue)]
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
}

