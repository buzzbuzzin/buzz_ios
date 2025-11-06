//
//  NotificationPreferencesService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Supabase
import Combine

@MainActor
class NotificationPreferencesService: ObservableObject {
    @Published var preferences: NotificationPreferences
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseClient.shared.client
    
    init() {
        self.preferences = NotificationPreferences()
    }
    
    func loadPreferences(userId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Try to fetch preferences from database
            let records: [NotificationPreferencesRecord] = try await supabase
                .from("notification_preferences")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            if let record = records.first {
                var prefs = NotificationPreferences()
                prefs.bookingReminders = NotificationDeliveryOptions(
                    system: record.bookingRemindersSystem,
                    email: record.bookingRemindersEmail,
                    text: record.bookingRemindersText
                )
                prefs.weatherUpdates = NotificationDeliveryOptions(
                    system: record.weatherUpdatesSystem,
                    email: record.weatherUpdatesEmail,
                    text: record.weatherUpdatesText
                )
                prefs.receivedReviews = NotificationDeliveryOptions(
                    system: record.receivedReviewsSystem,
                    email: record.receivedReviewsEmail,
                    text: record.receivedReviewsText
                )
                prefs.rankImprovements = NotificationDeliveryOptions(
                    system: record.rankImprovementsSystem,
                    email: record.rankImprovementsEmail,
                    text: record.rankImprovementsText
                )
                prefs.bookingUpdates = NotificationDeliveryOptions(
                    system: record.bookingUpdatesSystem,
                    email: record.bookingUpdatesEmail,
                    text: record.bookingUpdatesText
                )
                prefs.messages = NotificationDeliveryOptions(
                    system: record.messagesSystem,
                    email: record.messagesEmail,
                    text: record.messagesText
                )
                preferences = prefs
            }
            
            isLoading = false
        } catch {
            isLoading = false
            // If table doesn't exist or no preferences found, use defaults
            preferences = NotificationPreferences()
            errorMessage = nil // Don't show error for missing preferences
        }
    }
    
    func savePreferences(userId: UUID) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let record: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "booking_reminders_system": .bool(preferences.bookingReminders.system),
                "booking_reminders_email": .bool(preferences.bookingReminders.email),
                "booking_reminders_text": .bool(preferences.bookingReminders.text),
                "weather_updates_system": .bool(preferences.weatherUpdates.system),
                "weather_updates_email": .bool(preferences.weatherUpdates.email),
                "weather_updates_text": .bool(preferences.weatherUpdates.text),
                "received_reviews_system": .bool(preferences.receivedReviews.system),
                "received_reviews_email": .bool(preferences.receivedReviews.email),
                "received_reviews_text": .bool(preferences.receivedReviews.text),
                "rank_improvements_system": .bool(preferences.rankImprovements.system),
                "rank_improvements_email": .bool(preferences.rankImprovements.email),
                "rank_improvements_text": .bool(preferences.rankImprovements.text),
                "booking_updates_system": .bool(preferences.bookingUpdates.system),
                "booking_updates_email": .bool(preferences.bookingUpdates.email),
                "booking_updates_text": .bool(preferences.bookingUpdates.text),
                "messages_system": .bool(preferences.messages.system),
                "messages_email": .bool(preferences.messages.email),
                "messages_text": .bool(preferences.messages.text)
            ]
            
            // Check if preferences exist
            let existing: [NotificationPreferencesRecord] = try await supabase
                .from("notification_preferences")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            if existing.isEmpty {
                // Insert
                try await supabase
                    .from("notification_preferences")
                    .insert(record)
                    .execute()
            } else {
                // Update
                try await supabase
                    .from("notification_preferences")
                    .update(record)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// Database record structure
struct NotificationPreferencesRecord: Codable {
    let userId: UUID
    let bookingRemindersSystem: Bool
    let bookingRemindersEmail: Bool
    let bookingRemindersText: Bool
    let weatherUpdatesSystem: Bool
    let weatherUpdatesEmail: Bool
    let weatherUpdatesText: Bool
    let receivedReviewsSystem: Bool
    let receivedReviewsEmail: Bool
    let receivedReviewsText: Bool
    let rankImprovementsSystem: Bool
    let rankImprovementsEmail: Bool
    let rankImprovementsText: Bool
    let bookingUpdatesSystem: Bool
    let bookingUpdatesEmail: Bool
    let bookingUpdatesText: Bool
    let messagesSystem: Bool
    let messagesEmail: Bool
    let messagesText: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case bookingRemindersSystem = "booking_reminders_system"
        case bookingRemindersEmail = "booking_reminders_email"
        case bookingRemindersText = "booking_reminders_text"
        case weatherUpdatesSystem = "weather_updates_system"
        case weatherUpdatesEmail = "weather_updates_email"
        case weatherUpdatesText = "weather_updates_text"
        case receivedReviewsSystem = "received_reviews_system"
        case receivedReviewsEmail = "received_reviews_email"
        case receivedReviewsText = "received_reviews_text"
        case rankImprovementsSystem = "rank_improvements_system"
        case rankImprovementsEmail = "rank_improvements_email"
        case rankImprovementsText = "rank_improvements_text"
        case bookingUpdatesSystem = "booking_updates_system"
        case bookingUpdatesEmail = "booking_updates_email"
        case bookingUpdatesText = "booking_updates_text"
        case messagesSystem = "messages_system"
        case messagesEmail = "messages_email"
        case messagesText = "messages_text"
    }
}

