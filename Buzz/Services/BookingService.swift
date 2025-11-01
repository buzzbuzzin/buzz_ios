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
    }
    
    // MARK: - Fetch My Bookings
    
    func fetchMyBookings(userId: UUID, isPilot: Bool) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let bookings: [Booking] = try await supabase
                .from("bookings")
                .select()
                .eq(isPilot ? "pilot_id" : "customer_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.myBookings = bookings
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

