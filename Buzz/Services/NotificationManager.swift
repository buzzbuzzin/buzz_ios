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
        case bookingCancelled = "BOOKING_CANCELLED"
        case newMessage = "NEW_MESSAGE"
        case nearbyBooking = "NEARBY_BOOKING"
        case droneActivity = "DRONE_ACTIVITY"
        case weatherChange = "WEATHER_CHANGE"
        case receivedReview = "RECEIVED_REVIEW"
        case crewBookingAccepted = "CREW_BOOKING_ACCEPTED"
        case crewBookingCompleted = "CREW_BOOKING_COMPLETED"
        case tipReceived = "TIP_RECEIVED"
        case payoutConfirmation = "PAYOUT_CONFIRMATION"
        case emergencyBeacon = "EMERGENCY_BEACON"
        case emergencyBeaconUrgent = "EMERGENCY_BEACON_URGENT"
        case beaconAccepted = "BEACON_ACCEPTED"
        case beaconResolved = "BEACON_RESOLVED"
        case hangerTalkLike = "HANGER_TALK_LIKE"
        case hangerTalkReply = "HANGER_TALK_REPLY"
        case hangerTalkMention = "HANGER_TALK_MENTION"
        case hangerTalkFollow = "HANGER_TALK_FOLLOW"
        case hangerTalkNewPost = "HANGER_TALK_NEW_POST"
        case hangerTalkSpaceLive = "HANGER_TALK_SPACE_LIVE"
        case marketplaceNewOffer = "MARKETPLACE_NEW_OFFER"
        case marketplaceOfferAccepted = "MARKETPLACE_OFFER_ACCEPTED"
        case marketplaceOfferDeclined = "MARKETPLACE_OFFER_DECLINED"
        case marketplaceItemPurchased = "MARKETPLACE_ITEM_PURCHASED"
        case marketplaceItemShipped = "MARKETPLACE_ITEM_SHIPPED"
        case marketplaceDeliveryConfirmed = "MARKETPLACE_DELIVERY_CONFIRMED"
        case marketplaceReviewReceived = "MARKETPLACE_REVIEW_RECEIVED"
        case licenseApproved = "LICENSE_APPROVED"
        case licenseRejected = "LICENSE_REJECTED"
    }
    
    // Published property for emergency flash effect
    @Published var showEmergencyFlash: Bool = false
    @Published var emergencyBookingId: UUID?
    
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
    func notifyBookingAccepted(bookingId: UUID, pilotCallSign: String, aircraftType: String, departureTime: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Booking Accepted! ✈️"
        content.body = "\(pilotCallSign) has accepted your booking for \(aircraftType)"
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
    func scheduleBookingReminder(bookingId: UUID, aircraftType: String, departureTime: Date, pilotCallSign: String) async {
        // Calculate 24 hours before departure
        let reminderTime = departureTime.addingTimeInterval(-24 * 60 * 60)

        // Only schedule if reminder time is in the future
        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Flight Tomorrow"
        content.body = "Your \(aircraftType) flight with \(pilotCallSign) is scheduled for tomorrow"
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

    /// Notify pilot about an active NWS weather alert
    func notifyWeatherAlert(alertId: String, event: String, headline: String?, severity: String, areaDesc: String?) async {
        let content = UNMutableNotificationContent()

        switch severity.lowercased() {
        case "extreme":
            content.title = "Extreme Weather Alert"
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        case "severe":
            content.title = "Severe Weather Alert"
            content.sound = .defaultCritical
        default:
            content.title = "Weather Advisory"
            content.sound = .default
        }

        content.body = headline ?? "\(event) for \(areaDesc ?? "your area")"
        content.categoryIdentifier = NotificationCategory.weatherChange.rawValue
        content.userInfo = [
            "type": "nws_weather_alert",
            "alertId": alertId,
            "event": event,
            "severity": severity
        ]

        let request = UNNotificationRequest(
            identifier: "nws-alert-\(alertId.hashValue)",
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
    
    // MARK: - Beacon Emergency Notifications
    
    /// Notify beacon volunteer about a nearby emergency booking (standard priority)
    func notifyEmergencyBooking(
        bookingId: UUID,
        location: String,
        distanceMiles: Double,
        missionType: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "🚨 Emergency Response Needed"
        let distanceText = String(format: "%.1f miles", distanceMiles)
        content.body = "\(missionType) mission \(distanceText) away near \(location)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.emergencyBeacon.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "emergency_beacon",
            "location": location,
            "distanceMiles": distanceMiles,
            "missionType": missionType
        ]
        
        let request = UNNotificationRequest(
            identifier: "emergency-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
    
    /// Notify beacon volunteer about an urgent emergency - bypasses DND with critical alert
    func notifyUrgentEmergency(
        bookingId: UUID,
        location: String,
        distanceMiles: Double,
        missionType: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "🆘 URGENT: Emergency Response"
        let distanceText = String(format: "%.1f miles", distanceMiles)
        content.body = "CRITICAL \(missionType) mission \(distanceText) away near \(location). Immediate response needed!"
        
        // Use critical alert sound - bypasses Do Not Disturb
        content.sound = .defaultCritical
        content.categoryIdentifier = NotificationCategory.emergencyBeaconUrgent.rawValue
        content.interruptionLevel = .critical
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "emergency_beacon_urgent",
            "location": location,
            "distanceMiles": distanceMiles,
            "missionType": missionType,
            "isUrgent": true
        ]
        
        let request = UNNotificationRequest(
            identifier: "urgent-emergency-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
        
        // Trigger flash effect for urgent emergencies
        await triggerEmergencyFlash(bookingId: bookingId)
    }
    
    /// Trigger a flashing screen effect for urgent emergencies
    private func triggerEmergencyFlash(bookingId: UUID) async {
        await MainActor.run {
            self.emergencyBookingId = bookingId
            self.showEmergencyFlash = true
        }
        
        // Flash for 3 seconds
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        await MainActor.run {
            self.showEmergencyFlash = false
        }
    }
    
    /// Stop the emergency flash effect
    func stopEmergencyFlash() {
        showEmergencyFlash = false
        emergencyBookingId = nil
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
    
    // MARK: - Remote Push Notification Helper

    private struct PushNotificationRequest: Codable {
        let user_id: String
        let title: String
        let body: String
        let data: [String: String]?
    }

    /// Send a remote push notification to a specific user via the Supabase edge function
    func sendRemotePushNotification(
        recipientUserId: UUID,
        title: String,
        body: String,
        data: [String: String] = [:]
    ) async {
        let request = PushNotificationRequest(
            user_id: recipientUserId.uuidString,
            title: title,
            body: body,
            data: data.isEmpty ? nil : data
        )

        do {
            try await supabase.functions.invoke(
                "send-push-notification",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            print("Error sending remote push notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Hanger Talk Notifications

    /// Notify post author when someone likes their post (remote push to post author)
    func notifyHangerTalkLike(postId: UUID, postAuthorId: UUID, likerCallSign: String) async {
        await sendRemotePushNotification(
            recipientUserId: postAuthorId,
            title: "New Like",
            body: "\(likerCallSign) liked your post",
            data: [
                "postId": postId.uuidString,
                "type": "hanger_talk_like"
            ]
        )
    }

    /// Notify post author when someone replies to their post (remote push to parent post author)
    func notifyHangerTalkReply(postId: UUID, parentPostId: UUID, parentAuthorId: UUID, replierCallSign: String) async {
        await sendRemotePushNotification(
            recipientUserId: parentAuthorId,
            title: "New Reply",
            body: "\(replierCallSign) replied to your post",
            data: [
                "postId": postId.uuidString,
                "parentPostId": parentPostId.uuidString,
                "type": "hanger_talk_reply"
            ]
        )
    }

    /// Notify user when they are @mentioned in a post (remote push to mentioned user)
    func notifyHangerTalkMention(postId: UUID, mentionedUserId: UUID, mentionerCallSign: String) async {
        await sendRemotePushNotification(
            recipientUserId: mentionedUserId,
            title: "You Were Mentioned",
            body: "\(mentionerCallSign) mentioned you in a post",
            data: [
                "postId": postId.uuidString,
                "type": "hanger_talk_mention"
            ]
        )
    }

    /// Notify user when someone follows them (remote push to the followed user)
    func notifyHangerTalkFollow(followerCallSign: String, followedUserId: UUID) async {
        await sendRemotePushNotification(
            recipientUserId: followedUserId,
            title: "New Follower",
            body: "\(followerCallSign) started following you",
            data: [
                "type": "hanger_talk_follow"
            ]
        )
    }

    // MARK: - Marketplace Notifications

    func notifyMarketplaceNewOffer(recipientUserId: UUID, listingTitle: String, offerAmount: Decimal, buyerName: String, listingId: UUID, offerId: UUID? = nil) async {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let amountStr = formatter.string(from: offerAmount as NSDecimalNumber) ?? "$\(offerAmount)"
        var data: [String: String] = [
            "type": "marketplace_new_offer",
            "listing_id": listingId.uuidString
        ]
        if let offerId = offerId {
            data["offer_id"] = offerId.uuidString
        }
        await sendRemotePushNotification(
            recipientUserId: recipientUserId,
            title: "New Offer",
            body: "\(buyerName) offered \(amountStr) for \(listingTitle)",
            data: data
        )
    }

    func notifyMarketplaceOfferAccepted(recipientUserId: UUID, listingTitle: String, listingId: UUID, offerId: UUID, transactionId: UUID? = nil) async {
        var data: [String: String] = [
            "type": "marketplace_offer_accepted",
            "listing_id": listingId.uuidString,
            "offer_id": offerId.uuidString
        ]
        if let transactionId = transactionId {
            data["transaction_id"] = transactionId.uuidString
        }
        await sendRemotePushNotification(
            recipientUserId: recipientUserId,
            title: "Offer Accepted",
            body: "Your offer on \(listingTitle) was accepted!",
            data: data
        )
    }

    func notifyMarketplaceOfferDeclined(recipientUserId: UUID, listingTitle: String, listingId: UUID, offerId: UUID) async {
        await sendRemotePushNotification(
            recipientUserId: recipientUserId,
            title: "Offer Declined",
            body: "Your offer on \(listingTitle) was declined",
            data: [
                "type": "marketplace_offer_declined",
                "listing_id": listingId.uuidString,
                "offer_id": offerId.uuidString
            ]
        )
    }

    func notifyMarketplaceItemPurchased(recipientUserId: UUID, listingTitle: String, buyerName: String, listingId: UUID, transactionId: UUID) async {
        await sendRemotePushNotification(
            recipientUserId: recipientUserId,
            title: "Item Sold!",
            body: "\(buyerName) purchased \(listingTitle)",
            data: [
                "type": "marketplace_item_purchased",
                "listing_id": listingId.uuidString,
                "transaction_id": transactionId.uuidString
            ]
        )
    }

    func notifyMarketplaceItemShipped(recipientUserId: UUID, listingTitle: String, transactionId: UUID) async {
        await sendRemotePushNotification(
            recipientUserId: recipientUserId,
            title: "Item Shipped",
            body: "Your order for \(listingTitle) has been shipped",
            data: [
                "type": "marketplace_item_shipped",
                "transaction_id": transactionId.uuidString
            ]
        )
    }

    func notifyMarketplaceDeliveryConfirmed(recipientUserId: UUID, listingTitle: String, transactionId: UUID) async {
        await sendRemotePushNotification(
            recipientUserId: recipientUserId,
            title: "Delivery Confirmed",
            body: "Buyer confirmed receipt of \(listingTitle). Payment will be released.",
            data: [
                "type": "marketplace_delivery_confirmed",
                "transaction_id": transactionId.uuidString
            ]
        )
    }

    func notifyMarketplaceReviewReceived(recipientUserId: UUID, reviewerName: String, rating: Int, transactionId: UUID, reviewId: UUID? = nil) async {
        let stars = String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
        var data: [String: String] = [
            "type": "marketplace_review_received",
            "transaction_id": transactionId.uuidString
        ]
        if let reviewId = reviewId {
            data["review_id"] = reviewId.uuidString
        }
        await sendRemotePushNotification(
            recipientUserId: recipientUserId,
            title: "New Review",
            body: "\(reviewerName) left you a \(stars) review",
            data: data
        )
    }

    // MARK: - Booking Cancelled Notification

    /// Notify the other party that a booking has been cancelled
    func notifyBookingCancelled(bookingId: UUID, cancelledByName: String, aircraftType: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Booking Cancelled"
        content.body = "\(cancelledByName) cancelled the \(aircraftType) booking"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.bookingCancelled.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "booking_cancelled"
        ]

        let request = UNNotificationRequest(
            identifier: "booking-cancelled-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)
    }

    // MARK: - Tip Received Notification

    /// Notify pilot that they received a tip
    func notifyTipReceived(bookingId: UUID, tipAmount: Decimal, customerName: String) async {
        let content = UNMutableNotificationContent()
        let amountString = String(format: "$%.2f", NSDecimalNumber(decimal: tipAmount).doubleValue)
        content.title = "Tip Received! 🎉"
        content.body = "\(customerName) tipped you \(amountString)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.tipReceived.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "tip_received"
        ]

        let request = UNNotificationRequest(
            identifier: "tip-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)
    }

    // MARK: - Payout Confirmation Notification

    /// Notify pilot that their payout has been transferred
    func notifyPayoutConfirmation(bookingId: UUID, payoutAmount: Decimal) async {
        let content = UNMutableNotificationContent()
        let amountString = String(format: "$%.2f", NSDecimalNumber(decimal: payoutAmount).doubleValue)
        content.title = "Payout Sent! 💰"
        content.body = "Your \(amountString) payout has been transferred to your account"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.payoutConfirmation.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "payout_confirmation"
        ]

        let request = UNNotificationRequest(
            identifier: "payout-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)
    }

    // MARK: - Beacon Accepted Notification

    /// Notify the emergency creator that a volunteer has responded
    func notifyBeaconAccepted(bookingId: UUID, volunteerCallSign: String, missionType: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Help Is On The Way! 🚁"
        content.body = "\(volunteerCallSign) has accepted the \(missionType) mission"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.beaconAccepted.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "beacon_accepted"
        ]

        let request = UNNotificationRequest(
            identifier: "beacon-accepted-\(bookingId.uuidString)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)
    }

    // MARK: - Beacon Resolved Notification

    /// Notify participants that an emergency has been resolved
    func notifyBeaconResolved(bookingId: UUID, missionType: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Mission Complete ✅"
        content.body = "The \(missionType) mission has been resolved. Thank you for your help!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.beaconResolved.rawValue
        content.userInfo = [
            "bookingId": bookingId.uuidString,
            "type": "beacon_resolved"
        ]

        let request = UNNotificationRequest(
            identifier: "beacon-resolved-\(bookingId.uuidString)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)
    }

    // MARK: - Hanger Talk New Post Notification

    /// Notify a follower that someone they follow posted (remote push to the follower)
    func notifyHangerTalkNewPost(postId: UUID, followerUserId: UUID, authorCallSign: String) async {
        await sendRemotePushNotification(
            recipientUserId: followerUserId,
            title: "New Post",
            body: "\(authorCallSign) shared a new post",
            data: [
                "postId": postId.uuidString,
                "type": "hanger_talk_new_post"
            ]
        )
    }

    // MARK: - Hanger Talk Space Live Notification

    /// Notify a follower that someone they follow started a live Space
    func notifyHangerTalkSpaceLive(spaceId: UUID, followerUserId: UUID, hostCallSign: String, spaceTitle: String) async {
        await sendRemotePushNotification(
            recipientUserId: followerUserId,
            title: "Live Space",
            body: "\(hostCallSign) is live: \(spaceTitle)",
            data: [
                "spaceId": spaceId.uuidString,
                "type": "hanger_talk_space_live"
            ]
        )
    }

    // MARK: - Utility Methods

    /// Check if a specific notification type is enabled in user preferences
    func isNotificationEnabled(preferences: NotificationPreferences, type: NotificationCategory) -> Bool {
        switch type {
        case .bookingAccepted, .bookingReminder:
            return preferences.bookingReminders.system
        case .bookingCancelled:
            return preferences.bookingCancellations.system
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
        case .tipReceived:
            return preferences.tipReceived.system
        case .payoutConfirmation:
            return preferences.payoutConfirmation.system
        case .emergencyBeacon, .emergencyBeaconUrgent:
            // Emergency notifications are always enabled for volunteers
            return true
        case .beaconAccepted:
            return preferences.beaconAccepted.system
        case .beaconResolved:
            return preferences.beaconResolved.system
        case .hangerTalkLike:
            return preferences.hangerTalkLikes.system
        case .hangerTalkReply:
            return preferences.hangerTalkReplies.system
        case .hangerTalkMention:
            return preferences.hangerTalkMentions.system
        case .hangerTalkFollow:
            return preferences.hangerTalkFollows.system
        case .hangerTalkNewPost:
            return preferences.hangerTalkNewPosts.system
        case .hangerTalkSpaceLive:
            return preferences.hangerTalkSpaces.system
        case .marketplaceNewOffer, .marketplaceOfferAccepted, .marketplaceOfferDeclined:
            return preferences.marketplaceOffers.system
        case .marketplaceItemPurchased, .marketplaceItemShipped, .marketplaceDeliveryConfirmed:
            return preferences.marketplaceTransactions.system
        case .marketplaceReviewReceived:
            return preferences.marketplaceReviews.system
        case .licenseApproved, .licenseRejected:
            // License approval notifications are always enabled
            return true
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
        // For remote push notifications, the custom data is nested under "data" key
        var resolvedInfo = userInfo
        if let data = userInfo["data"] as? [String: Any] {
            // Merge data fields into top level for consistent handling
            for (key, value) in data {
                resolvedInfo[key] = value
            }
        }

        DeepLinkManager.shared.handleNotificationTap(userInfo: resolvedInfo)
    }
}

