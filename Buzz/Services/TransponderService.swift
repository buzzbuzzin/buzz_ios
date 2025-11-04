//
//  TransponderService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import CoreLocation
import Combine

@MainActor
class TransponderService: ObservableObject {
    @Published var transponders: [Transponder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch Transponders
    
    func fetchTransponders(pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        // TODO: DEMO MODE - Replace this sample data with real backend call
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // SAMPLE DATA FOR DEMO PURPOSES - Replace with real Supabase query when ready
        let sampleTransponders = createSampleTransponders(pilotId: pilotId)
        
        await MainActor.run {
            self.transponders = sampleTransponders
            self.isLoading = false
        }
        
        return
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            let transponders: [Transponder] = try await supabase
                .from("transponders")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.transponders = transponders
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
        */
    }
    
    // MARK: - Fetch All Active Transponders (for Flight Radar)
    
    func fetchAllActiveTransponders() async throws -> [Transponder] {
        // TODO: DEMO MODE - Replace this sample data with real backend call
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // SAMPLE DATA FOR DEMO PURPOSES - Create transponders from multiple pilots
        // In production, this would fetch all transponders with location tracking enabled
        // and recent location updates (within last 15 minutes)
        let now = Date()
        let sampleTransponders = [
            // Pilot 1's active drone
            Transponder(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                pilotId: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") ?? UUID(),
                deviceName: "DJI Mavic 3 Pro",
                remoteId: "RID-3C4F5A6B-7D8E-9F0A-1B2C-3D4E5F6A7B8C",
                isLocationTrackingEnabled: true,
                lastLocationLat: 37.7749,
                lastLocationLng: -122.4194,
                lastLocationUpdate: now.addingTimeInterval(-120), // 2 minutes ago
                speed: 12.5, // m/s (~45 km/h)
                altitude: 85.0, // meters
                createdAt: now.addingTimeInterval(-86400 * 30)
            ),
            // Pilot 2's active drone
            Transponder(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                pilotId: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb") ?? UUID(),
                deviceName: "DJI Phantom 4 Pro",
                remoteId: "RID-9A8B7C6D-5E4F-3A2B-1C0D-9E8F7A6B5C4D",
                isLocationTrackingEnabled: true,
                lastLocationLat: 34.0522,
                lastLocationLng: -118.2437,
                lastLocationUpdate: now.addingTimeInterval(-300), // 5 minutes ago
                speed: 8.3, // m/s (~30 km/h)
                altitude: 120.0, // meters
                createdAt: now.addingTimeInterval(-86400 * 60)
            ),
            // Pilot 3's active drone
            Transponder(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
                pilotId: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc") ?? UUID(),
                deviceName: "Autel EVO Lite+",
                remoteId: "RID-1F2E3D4C-5B6A-7890-ABCD-EF1234567890",
                isLocationTrackingEnabled: true,
                lastLocationLat: 40.7128,
                lastLocationLng: -74.0060,
                lastLocationUpdate: now.addingTimeInterval(-60), // 1 minute ago
                speed: 15.0, // m/s (~54 km/h)
                altitude: 65.0, // meters
                createdAt: now.addingTimeInterval(-86400 * 15)
            ),
            // Pilot 4's active drone
            Transponder(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
                pilotId: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd") ?? UUID(),
                deviceName: "Skydio 2+",
                remoteId: "RID-A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
                isLocationTrackingEnabled: true,
                lastLocationLat: 37.7849,
                lastLocationLng: -122.4094,
                lastLocationUpdate: now.addingTimeInterval(-180), // 3 minutes ago
                speed: 10.8, // m/s (~39 km/h)
                altitude: 45.0, // meters
                createdAt: now.addingTimeInterval(-86400 * 7)
            ),
            // Pilot 5's active drone
            Transponder(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
                pilotId: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee") ?? UUID(),
                deviceName: "DJI Mini 3",
                remoteId: "RID-B2C3D4E5-F6A7-8901-BCDE-F12345678901",
                isLocationTrackingEnabled: true,
                lastLocationLat: 40.7580,
                lastLocationLng: -73.9855,
                lastLocationUpdate: now.addingTimeInterval(-90), // 1.5 minutes ago
                speed: 6.9, // m/s (~25 km/h)
                altitude: 30.0, // meters
                createdAt: now.addingTimeInterval(-86400 * 10)
            )
        ]
        
        // Filter to only active drones (location tracking enabled and recent update within 15 minutes)
        let activeTransponders = sampleTransponders.filter { transponder in
            guard transponder.isLocationTrackingEnabled,
                  let lastUpdate = transponder.lastLocationUpdate,
                  let _ = transponder.lastLocation else {
                return false
            }
            // Consider active if updated within last 15 minutes
            return Date().timeIntervalSince(lastUpdate) < 15 * 60
        }
        
        return activeTransponders
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
            let isoFormatter = ISO8601DateFormatter()
            let dateString = isoFormatter.string(from: fifteenMinutesAgo)
            
            let transponders: [Transponder] = try await supabase
                .from("transponders")
                .select()
                .eq("is_location_tracking_enabled", value: true)
                .gte("last_location_update", value: dateString)
                .not("last_location_lat", operator: .is, value: nil)
                .not("last_location_lng", operator: .is, value: nil)
                .order("last_location_update", ascending: false)
                .execute()
                .value
            
            return transponders
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        */
    }
    
    // MARK: - Sample Data for Demo (Transponders)
    // TODO: Remove this function when connecting to real backend
    
    private func createSampleTransponders(pilotId: UUID) -> [Transponder] {
        let calendar = Calendar.current
        let now = Date()
        
        // Create sample transponders with realistic data
        return [
            Transponder(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                pilotId: pilotId,
                deviceName: "DJI Mavic 3 Pro",
                remoteId: "RID-3C4F5A6B-7D8E-9F0A-1B2C-3D4E5F6A7B8C",
                isLocationTrackingEnabled: true,
                lastLocationLat: 37.7749,
                lastLocationLng: -122.4194,
                lastLocationUpdate: now.addingTimeInterval(-300), // 5 minutes ago
                speed: 12.5,
                altitude: 85.0,
                createdAt: calendar.date(byAdding: .day, value: -30, to: now) ?? now
            ),
            Transponder(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                pilotId: pilotId,
                deviceName: "DJI Phantom 4 Pro",
                remoteId: "RID-9A8B7C6D-5E4F-3A2B-1C0D-9E8F7A6B5C4D",
                isLocationTrackingEnabled: false,
                lastLocationLat: nil,
                lastLocationLng: nil,
                lastLocationUpdate: nil,
                speed: nil,
                altitude: nil,
                createdAt: calendar.date(byAdding: .day, value: -60, to: now) ?? now
            ),
            Transponder(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
                pilotId: pilotId,
                deviceName: "Autel EVO Lite+",
                remoteId: "RID-1F2E3D4C-5B6A-7890-ABCD-EF1234567890",
                isLocationTrackingEnabled: true,
                lastLocationLat: 34.0522,
                lastLocationLng: -118.2437,
                lastLocationUpdate: now.addingTimeInterval(-600), // 10 minutes ago
                speed: 15.0,
                altitude: 65.0,
                createdAt: calendar.date(byAdding: .day, value: -15, to: now) ?? now
            ),
            Transponder(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
                pilotId: pilotId,
                deviceName: "Skydio 2+",
                remoteId: "RID-A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
                isLocationTrackingEnabled: true,
                lastLocationLat: 40.7128,
                lastLocationLng: -74.0060,
                lastLocationUpdate: now.addingTimeInterval(-120), // 2 minutes ago
                speed: 10.8,
                altitude: 45.0,
                createdAt: calendar.date(byAdding: .day, value: -7, to: now) ?? now
            )
        ]
    }
    
    // MARK: - Create Transponder
    
    func createTransponder(
        pilotId: UUID,
        deviceName: String,
        remoteId: String,
        isLocationTrackingEnabled: Bool = false
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        // TODO: DEMO MODE - In demo mode, add to local array instead of backend
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Create new transponder locally for demo
        let newTransponder = Transponder(
            id: UUID(),
            pilotId: pilotId,
            deviceName: deviceName,
            remoteId: remoteId,
            isLocationTrackingEnabled: isLocationTrackingEnabled,
            lastLocationLat: nil,
            lastLocationLng: nil,
            lastLocationUpdate: nil,
            speed: nil,
            altitude: nil,
            createdAt: Date()
        )
        
        await MainActor.run {
            self.transponders.insert(newTransponder, at: 0)
            self.isLoading = false
        }
        
        return
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            let transponder: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "device_name": .string(deviceName),
                "remote_id": .string(remoteId),
                "is_location_tracking_enabled": .bool(isLocationTrackingEnabled),
                "created_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            try await supabase
                .from("transponders")
                .insert(transponder)
                .execute()
            
            // Refresh the list
            try await fetchTransponders(pilotId: pilotId)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
        */
    }
    
    // MARK: - Update Transponder Location
    
    func updateTransponderLocation(
        transponderId: UUID,
        location: CLLocationCoordinate2D
    ) async throws {
        // TODO: DEMO MODE - Update local array instead of backend
        await MainActor.run {
            if let index = transponders.firstIndex(where: { $0.id == transponderId }) {
                let updated = Transponder(
                    id: transponders[index].id,
                    pilotId: transponders[index].pilotId,
                    deviceName: transponders[index].deviceName,
                    remoteId: transponders[index].remoteId,
                    isLocationTrackingEnabled: transponders[index].isLocationTrackingEnabled,
                    lastLocationLat: location.latitude,
                    lastLocationLng: location.longitude,
                    lastLocationUpdate: Date(),
                    speed: transponders[index].speed,
                    altitude: transponders[index].altitude,
                    createdAt: transponders[index].createdAt
                )
                transponders[index] = updated
            }
        }
        
        return
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            let updateData: [String: AnyJSON] = [
                "last_location_lat": .double(location.latitude),
                "last_location_lng": .double(location.longitude),
                "last_location_update": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            try await supabase
                .from("transponders")
                .update(updateData)
                .eq("id", value: transponderId.uuidString)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        */
    }
    
    // MARK: - Update Transponder
    
    func updateTransponder(
        transponderId: UUID,
        deviceName: String,
        remoteId: String,
        isLocationTrackingEnabled: Bool
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        // TODO: DEMO MODE - Update local array instead of backend
        await MainActor.run {
            if let index = transponders.firstIndex(where: { $0.id == transponderId }) {
                let updated = Transponder(
                    id: transponders[index].id,
                    pilotId: transponders[index].pilotId,
                    deviceName: deviceName,
                    remoteId: remoteId,
                    isLocationTrackingEnabled: isLocationTrackingEnabled,
                    lastLocationLat: transponders[index].lastLocationLat,
                    lastLocationLng: transponders[index].lastLocationLng,
                    lastLocationUpdate: transponders[index].lastLocationUpdate,
                    speed: transponders[index].speed,
                    altitude: transponders[index].altitude,
                    createdAt: transponders[index].createdAt
                )
                transponders[index] = updated
            }
            self.isLoading = false
        }
        
        return
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            let updateData: [String: AnyJSON] = [
                "device_name": .string(deviceName),
                "remote_id": .string(remoteId),
                "is_location_tracking_enabled": .bool(isLocationTrackingEnabled)
            ]
            
            try await supabase
                .from("transponders")
                .update(updateData)
                .eq("id", value: transponderId.uuidString)
                .execute()
            
            // Refresh the list
            if let pilotId = transponders.first(where: { $0.id == transponderId })?.pilotId {
                try await fetchTransponders(pilotId: pilotId)
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
        */
    }
    
    // MARK: - Update Location Tracking Status
    
    func updateLocationTrackingStatus(
        transponderId: UUID,
        isEnabled: Bool
    ) async throws {
        // TODO: DEMO MODE - Update local array instead of backend
        await MainActor.run {
            if let index = transponders.firstIndex(where: { $0.id == transponderId }) {
                let updated = Transponder(
                    id: transponders[index].id,
                    pilotId: transponders[index].pilotId,
                    deviceName: transponders[index].deviceName,
                    remoteId: transponders[index].remoteId,
                    isLocationTrackingEnabled: isEnabled,
                    lastLocationLat: transponders[index].lastLocationLat,
                    lastLocationLng: transponders[index].lastLocationLng,
                    lastLocationUpdate: transponders[index].lastLocationUpdate,
                    speed: transponders[index].speed,
                    altitude: transponders[index].altitude,
                    createdAt: transponders[index].createdAt
                )
                transponders[index] = updated
            }
        }
        
        return
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            let updateData: [String: AnyJSON] = [
                "is_location_tracking_enabled": .bool(isEnabled)
            ]
            
            try await supabase
                .from("transponders")
                .update(updateData)
                .eq("id", value: transponderId.uuidString)
                .execute()
            
            // Refresh the list
            if let pilotId = transponders.first(where: { $0.id == transponderId })?.pilotId {
                try await fetchTransponders(pilotId: pilotId)
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        */
    }
    
    // MARK: - Delete Transponder
    
    func deleteTransponder(transponderId: UUID, pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        // TODO: DEMO MODE - Remove from local array instead of backend
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        await MainActor.run {
            transponders.removeAll { $0.id == transponderId }
            self.isLoading = false
        }
        
        return
        
        /* UNCOMMENT WHEN READY TO USE REAL BACKEND:
        do {
            try await supabase
                .from("transponders")
                .delete()
                .eq("id", value: transponderId.uuidString)
                .execute()
            
            // Refresh the list
            try await fetchTransponders(pilotId: pilotId)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
        */
    }
}

