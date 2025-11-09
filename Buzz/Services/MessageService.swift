//
//  MessageService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class MessageService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    // MARK: - Fetch Messages for Booking
    
    func fetchMessages(bookingId: UUID, pilotId: UUID, customerId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // Simulate API call delay
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // SAMPLE DATA FOR DEMO PURPOSES
            let sampleMessages = createSampleMessages(for: bookingId, pilotId: pilotId, customerId: customerId)
            
            await MainActor.run {
                self.messages = sampleMessages
                self.isLoading = false
            }
            return
        }
        
        // Real backend call
        do {
            let messages: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("booking_id", value: bookingId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            await MainActor.run {
                self.messages = messages
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
    
    // MARK: - Send Message
    
    func sendMessage(bookingId: UUID, fromUserId: UUID, toUserId: UUID, text: String) async throws {
        isLoading = true
        errorMessage = nil
        
        // Check if demo mode is enabled
        if DemoModeManager.shared.isDemoModeEnabled {
            // Add message to local array for demo
            let newMessage = Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: fromUserId,
                toUserId: toUserId,
                text: text,
                createdAt: Date(),
                isRead: false
            )
            
            await MainActor.run {
                self.messages.append(newMessage)
                self.isLoading = false
            }
            return
        }
        
        // Real backend call
        do {
            let messageData: [String: AnyJSON] = [
                "booking_id": .string(bookingId.uuidString),
                "from_user_id": .string(fromUserId.uuidString),
                "to_user_id": .string(toUserId.uuidString),
                "text": .string(text),
                "created_at": .string(ISO8601DateFormatter().string(from: Date())),
                "is_read": .bool(false)
            ]
            
            try await supabase
                .from("messages")
                .insert(messageData)
                .execute()
            
            await MainActor.run {
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
    
    // MARK: - Sample Data for Demo
    // TODO: Remove this function when connecting to real backend
    
    private func createSampleMessages(for bookingId: UUID, pilotId: UUID, customerId: UUID) -> [Message] {
        let calendar = Calendar.current
        let now = Date()
        
        // Create sample conversation history
        // Conversation starts with pilot, then alternates: pilot -> customer -> pilot -> customer
        return [
            Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: pilotId, // Pilot starts the conversation
                toUserId: customerId, // Customer
                text: "Hi! I saw your booking. Can you provide more details about the location?",
                createdAt: calendar.date(byAdding: .hour, value: -12, to: now) ?? now,
                isRead: true
            ),
            Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: customerId, // Customer replies
                toUserId: pilotId, // Pilot
                text: "Sure! The location is accessible and has good clearance for drone operations. Are there any specific shots you're looking for?",
                createdAt: calendar.date(byAdding: .hour, value: -11, to: now) ?? now,
                isRead: true
            ),
            Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: pilotId, // Pilot replies
                toUserId: customerId, // Customer
                text: "Yes, I'd like aerial shots of the building facade and surrounding area. Can you do that?",
                createdAt: calendar.date(byAdding: .hour, value: -10, to: now) ?? now,
                isRead: true
            ),
            Message(
                id: UUID(),
                bookingId: bookingId,
                fromUserId: customerId, // Customer replies
                toUserId: pilotId, // Pilot
                text: "Absolutely! I have experience with architectural photography. I'll make sure to capture all angles.",
                createdAt: calendar.date(byAdding: .hour, value: -9, to: now) ?? now,
                isRead: true
            )
        ]
    }
}

