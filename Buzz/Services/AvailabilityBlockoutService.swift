//
//  AvailabilityBlockoutService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class AvailabilityBlockoutService: ObservableObject {
    @Published var blockouts: [AvailabilityBlockout] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch Blockouts
    
    func fetchBlockouts(pilotId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let blockouts: [AvailabilityBlockout] = try await supabase
                .from("availability_blockouts")
                .select()
                .eq("pilot_id", value: pilotId.uuidString)
                .order("start_date", ascending: true)
                .execute()
                .value
            
            await MainActor.run {
                self.blockouts = blockouts
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
    
    // MARK: - Create Blockout
    
    func createBlockout(
        pilotId: UUID,
        label: String?,
        startDate: Date,
        endDate: Date,
        recurrenceType: RecurrenceType,
        recurrenceEndDate: Date?
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            var blockout: [String: AnyJSON] = [
                "id": .string(UUID().uuidString),
                "pilot_id": .string(pilotId.uuidString),
                "start_date": .string(ISO8601DateFormatter().string(from: startDate)),
                "end_date": .string(ISO8601DateFormatter().string(from: endDate)),
                "recurrence_type": .string(recurrenceType.rawValue),
                "recurrence_end_date": recurrenceEndDate != nil ? .string(ISO8601DateFormatter().string(from: recurrenceEndDate!)) : .null
            ]
            
            if let label = label, !label.isEmpty {
                blockout["label"] = .string(label)
            } else {
                blockout["label"] = .null
            }
            
            let created: AvailabilityBlockout = try await supabase
                .from("availability_blockouts")
                .insert(blockout)
                .select()
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.blockouts.append(created)
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
    
    // MARK: - Update Blockout
    
    func updateBlockout(
        blockoutId: UUID,
        label: String?,
        startDate: Date,
        endDate: Date,
        recurrenceType: RecurrenceType,
        recurrenceEndDate: Date?
    ) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            var updates: [String: AnyJSON] = [
                "start_date": .string(ISO8601DateFormatter().string(from: startDate)),
                "end_date": .string(ISO8601DateFormatter().string(from: endDate)),
                "recurrence_type": .string(recurrenceType.rawValue),
                "recurrence_end_date": recurrenceEndDate != nil ? .string(ISO8601DateFormatter().string(from: recurrenceEndDate!)) : .null
            ]
            
            if let label = label, !label.isEmpty {
                updates["label"] = .string(label)
            } else {
                updates["label"] = .null
            }
            
            let updated: AvailabilityBlockout = try await supabase
                .from("availability_blockouts")
                .update(updates)
                .eq("id", value: blockoutId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            await MainActor.run {
                if let index = self.blockouts.firstIndex(where: { $0.id == blockoutId }) {
                    self.blockouts[index] = updated
                }
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
    
    // MARK: - Delete Blockout
    
    func deleteBlockout(blockoutId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase
                .from("availability_blockouts")
                .delete()
                .eq("id", value: blockoutId.uuidString)
                .execute()
            
            await MainActor.run {
                self.blockouts.removeAll { $0.id == blockoutId }
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
    
    // MARK: - Check if Date is Blocked
    
    func isDateBlocked(_ date: Date) -> Bool {
        return blockouts.contains { $0.contains(date: date) }
    }
    
    // MARK: - Get Blockouts for Date
    
    func getBlockouts(for date: Date) -> [AvailabilityBlockout] {
        return blockouts.filter { $0.contains(date: date) }
    }
}

