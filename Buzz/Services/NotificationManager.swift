//
//  NotificationManager.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/25/25.
//

import Foundation
import UserNotifications
import Combine
import UIKit
import Supabase
import Auth
import PostgREST

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var hasRequestedPermission = false
    @Published var deviceToken: String?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let supabase = SupabaseClient.shared.client
    
    // Notification category identifiers
    enum NotificationCategory: String {
        case bookingAccepted = "BOOKING_ACCEPTED"
        case bookingReminder = "BOOKING_REMINDER"
        case newMessage = "NEW_MESSAGE"
        case nearbyBooking = "NEARBY_BOOKING"
        case droneActivity = "DRONE_ACTIVITY"
        case weatherChange = "WEATHER_CHANGE"
        case receivedReview = "RECEIVED_REVIEW"
        case crewBookingAccepted = "CREW_BOOKING_ACCEPTED"
        case crewBookingCompleted = "CREW_BOOKING_COMPLETED"
        case videoUploadReminder = "VIDEO_UPLOAD_REMINDER"
    }
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - Permission Management
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await updateAuthorizationStatus()
            hasRequestedPermission = true
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            hasRequestedPermission = true
            return false
        }
    }
    
    // MARK: - Remote Notification Registration
    
    /// Register for remote notifications (APNs)
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    /// Handle successful device token registration
    /// Called from AppDelegate when APNs returns a device token
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("APNs Device Token: \(tokenString)")
        
        // Save token to database
        Task {
            await saveDeviceTokenToDatabase(token: tokenString)
        }
    }
    
    /// Handle failed device token registration
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    /// Save the device token to Supabase database
    private func saveDeviceTokenToDatabase(token: String) async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // Use the upsert_device_token function
            try await supabase
                .rpc("upsert_device_token", params: [
                    "p_user_id": userId.uuidString,
                    "p_token": token,
                    "p_platform": "ios"
                ])
                .execute()
            
            print("Device token saved successfully for user: \(userId)")
        } catch {
            print("Error saving device token: \(error.localizedDescription)")
        }
    }
    
    /// Remove the current device token from database (e.g., on logout)
    func removeDeviceToken() async {
        guard let token = deviceToken else { return }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            try await supabase
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("token", value: token)
                .execute()
            
            self.deviceToken = nil
            print("Device token removed successfully")
        } catch {
            print("Error removing device token: \(error.localizedDescription)")
        }
    }
    
    func updateAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        await updateAuthorizationStatus()
        return authorizationStatus
    }
    
    // MARK: - Client Notifications
    
    /// Notify client that their booking has been accepted by a pilot
    func notifyBookingAccepted(bookingId: UUID, pilotName: String, aircraftType: String, departureTime: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Booking Accepted! ✈️"
        content.body = "\(pilotName) has accepted your booking for \(aircraftType)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.bookingAccepted.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "booking_accepted"
        ]
        
        let request = UNNotificationRequest(
            identifier: "booking-accepted-\(bookingId.uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        try? await notificationCenter.add(request)
    }
    
    /// Schedule a 24-hour reminder for an upcoming booking
    func scheduleBookingReminder(bookingId: UUID, aircraftType: String, departureTime: Date, pilotName: String) async {
        // Calculate 24 hours before departure
        let reminderTime = departureTime.addingTimeInterval(-24 * 60 * 60)
        
        // Only schedule if reminder time is in the future
        guard reminderTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Flight Tomorrow"
        content.body = "Your \(aircraftType) flight with \(pilotName) is scheduled for tomorrow"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.bookingReminder.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "booking_reminder"
        ]
        
        let timeInterval = reminderTime.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "booking-reminder-\(bookingId.uuidString)",
            content: content,
            trigger: trigger
        )
        
        try? await notificationCenter.add(request)
    }
    
    /// Cancel a booking reminder (e.g., when booking is cancelled)
    func cancelBookingReminder(bookingId: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "booking-reminder-\(bookingId.uuidString)"
        ])
    }
    
    // MARK: - Pilot Notifications
    
    /// Notify pilot about a new available booking nearby
    func notifyNearbyBooking(bookingId: UUID, aircraftType: String, distance: Double, departureTime: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "New Booking Available"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        // If distance is 0, it means we notified all pilots (no location filtering)
        if distance > 0 {
            let distanceText = String(format: "%.1f miles", distance)
            content.body = "\(aircraftType) • \(distanceText) away • \(dateFormatter.string(from: departureTime))"
        } else {
            content.body = "\(aircraftType) • \(dateFormatter.string(from: departureTime))"
        }
        
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.nearbyBooking.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "nearby_booking"
        ]
        
        let request = UNNotificationRequest(
            identifier: "nearby-booking-\(bookingId.uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        try? await notificationCenter.add(request)
    }
    
    /// Notify pilot about nearby drone activity
    func notifyDroneActivity(location: String, altitude: Int, distance: Double) async {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Drone Activity Nearby"
        let distanceText = String(format: "%.1f miles", distance)
        content.body = "Drone detected \(distanceText) away at \(altitude) ft near \(location)"
        content.sound = .defaultCritical // Critical sound for safety alerts
        content.categoryIdentifier = NotificationCategory.droneActivity.rawValue
        content.userInfo = [
            "type": "drone_activity",
            "location": location,
            "altitude": altitude
        ]
        
        let request = UNNotificationRequest(
            identifier: "drone-activity-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    /// Notify pilot about weather changes
    func notifyWeatherChange(condition: String, location: String, severity: String = "moderate") async {
        let content = UNMutableNotificationContent()
        
        switch severity.lowercased() {
        case "severe", "critical":
            content.title = "⚠️ Severe Weather Alert"
            content.sound = .defaultCritical
        default:
            content.title = "Weather Update"
            content.sound = .default
        }
        
        content.body = "\(condition) near \(location)"
        content.categoryIdentifier = NotificationCategory.weatherChange.rawValue
        content.userInfo = [
            "type": "weather_change",
            "condition": condition,
            "location": location
        ]
        
        let request = UNNotificationRequest(
            identifier: "weather-change-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    /// Notify pilot when they receive a new review
    func notifyReceivedReview(rating: Int, reviewerName: String, bookingId: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = "New Review Received"
        let stars = String(repeating: "⭐", count: rating)
        content.body = "\(stars) from \(reviewerName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.receivedReview.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "received_review",
            "rating": rating
        ]
        
        let request = UNNotificationRequest(
            identifier: "review-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    // MARK: - Automotive Crew Booking Notifications
    
    /// Notify crew member that their automotive booking crew is complete and booking is accepted
    /// Called when the 4th pilot joins and the crew has a qualified lead (Lieutenant+)
    func notifyCrewBookingAccepted(bookingId: UUID, crewCount: Int, role: String, scheduledDate: Date?) async {
        let content = UNMutableNotificationContent()
        content.title = "Crew Complete! 🚗"
        
        let roleText = role == "lead" ? "You're the Lead Pilot" : "You're part of the crew"
        if let date = scheduledDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            content.body = "\(roleText) for the automotive booking on \(dateFormatter.string(from: date))"
        } else {
            content.body = "\(roleText). All \(crewCount) pilots are ready!"
        }
        
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.crewBookingAccepted.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "crew_booking_accepted",
            "role": role
        ]
        
        let request = UNNotificationRequest(
            identifier: "crew-accepted-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    /// Notify crew member that their automotive booking has been completed
    /// Earnings will be visible in their Balance view
    func notifyCrewBookingCompleted(bookingId: UUID, payoutAmount: Decimal, role: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Booking Completed! 🎉"
        
        let amountString = String(format: "$%.0f", NSDecimalNumber(decimal: payoutAmount).doubleValue)
        content.body = "Great job! You earned \(amountString) from this automotive booking. View details in your Balance."
        
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.crewBookingCompleted.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "crew_booking_completed",
            "payoutAmount": NSDecimalNumber(decimal: payoutAmount).doubleValue,
            "role": role
        ]
        
        let request = UNNotificationRequest(
            identifier: "crew-completed-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    // MARK: - Message Notifications (Both Client & Pilot)
    
    /// Notify user about a new message
    func notifyNewMessage(senderName: String, messagePreview: String, conversationId: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = "New Message from \(senderName)"
        content.body = messagePreview
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.newMessage.rawValue
        content.userInfo = [
            "conversationId": conversationId.uuidString,
            "type": "new_message"
        ]
        
        let request = UNNotificationRequest(
            identifier: "message-\(conversationId.uuidString)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    // MARK: - Utility Methods
    
    /// Check if a specific notification type is enabled in user preferences
    func isNotificationEnabled(preferences: NotificationPreferences, type: NotificationCategory) -> Bool {
        switch type {
        case .bookingAccepted, .bookingReminder:
            return preferences.bookingReminders.system
        case .newMessage:
            return preferences.messages.system
        case .nearbyBooking:
            return preferences.bookingUpdates.system
        case .droneActivity, .weatherChange:
            return preferences.weatherUpdates.system
        case .receivedReview:
            return preferences.receivedReviews.system
        case .crewBookingAccepted, .crewBookingCompleted:
            return preferences.bookingReminders.system
        case .videoUploadReminder:
            return preferences.bookingReminders.system
        }
    }
    
    /// Remove all pending notifications
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    /// Remove all delivered notifications
    func removeAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    /// Get count of pending notifications
    func getPendingNotificationsCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle navigation based on notification type
        Task { @MainActor in
            await handleNotificationTap(userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    /// Handle notification tap and navigate to appropriate screen
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        guard let type = userInfo["type"] as? String else { return }
        
        // Post notification for app to handle navigation
        NotificationCenter.default.post(
            name: NSNotification.Name("HandleNotificationTap"),
            object: nil,
            userInfo: userInfo
        )
        
        print("Notification tapped: \(type)")
        // Navigation handling will be done in the app's main view
    }
}

