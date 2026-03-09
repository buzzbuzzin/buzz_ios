//
//  DeepLinkManager.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/12/26.
//

import Foundation
import Combine

/// Represents a deep link destination triggered by a push notification tap
enum DeepLinkDestination: Equatable {
    case weather
    case flightRadar
    case hangerTalkPost(postId: UUID)
    case hangerTalkProfile(userId: UUID)
    case hangerTalkInbox
    case hangerTalkSpace(spaceId: UUID)
    case bookingDetail(bookingId: UUID)
    case messages(conversationId: UUID)
    case jobs
    case profile
    case licenseManagement(licenseId: UUID? = nil)
    case marketplace(listingId: UUID? = nil, transactionId: UUID? = nil, offerId: UUID? = nil, reviewId: UUID? = nil)
}

/// Manages deep link navigation state triggered by push notification taps.
/// Observed by views at different levels of the hierarchy to coordinate navigation.
@MainActor
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    /// The pending destination to navigate to. Views consume this by setting it to nil after handling.
    @Published var pendingDestination: DeepLinkDestination?

    private init() {}

    /// Parse notification userInfo and set the pending destination
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "booking_accepted", "booking_reminder", "booking_cancelled",
             "crew_booking_accepted", "crew_booking_completed",
             "tip_received", "payout_confirmation":
            if let bookingIdString = userInfo["bookingId"] as? String,
               let bookingId = UUID(uuidString: bookingIdString) {
                pendingDestination = .bookingDetail(bookingId: bookingId)
            }

        case "new_message", "message_reaction":
            if let conversationIdString = userInfo["conversationId"] as? String,
               let conversationId = UUID(uuidString: conversationIdString) {
                pendingDestination = .messages(conversationId: conversationId)
            }

        case "nearby_booking":
            pendingDestination = .jobs

        case "drone_activity":
            pendingDestination = .flightRadar

        case "weather_change", "nws_weather_alert":
            pendingDestination = .weather

        case "received_review":
            pendingDestination = .profile

        case "hanger_talk_like", "hanger_talk_mention", "hanger_talk_new_post":
            if let postIdString = userInfo["postId"] as? String,
               let postId = UUID(uuidString: postIdString) {
                pendingDestination = .hangerTalkPost(postId: postId)
            }

        case "hanger_talk_reply":
            // For replies, navigate to the parent post so the user sees the reply in context
            if let parentPostIdString = userInfo["parentPostId"] as? String,
               let parentPostId = UUID(uuidString: parentPostIdString) {
                pendingDestination = .hangerTalkPost(postId: parentPostId)
            } else if let postIdString = userInfo["postId"] as? String,
                      let postId = UUID(uuidString: postIdString) {
                pendingDestination = .hangerTalkPost(postId: postId)
            }

        case "hanger_talk_follow":
            pendingDestination = .hangerTalkInbox

        case "hanger_talk_space_live":
            if let spaceIdString = userInfo["spaceId"] as? String,
               let spaceId = UUID(uuidString: spaceIdString) {
                pendingDestination = .hangerTalkSpace(spaceId: spaceId)
            }

        case "emergency_beacon", "emergency_beacon_urgent",
             "beacon_accepted", "beacon_resolved":
            if let bookingIdString = userInfo["bookingId"] as? String,
               let bookingId = UUID(uuidString: bookingIdString) {
                pendingDestination = .bookingDetail(bookingId: bookingId)
            }

        case "license_approved", "license_rejected", "license_pre_approved":
            let licenseId = (userInfo["license_id"] as? String).flatMap(UUID.init)
            pendingDestination = .licenseManagement(licenseId: licenseId)

        case "marketplace_new_offer", "marketplace_offer_accepted", "marketplace_offer_declined",
             "marketplace_item_purchased", "marketplace_item_shipped",
             "marketplace_delivery_confirmed", "marketplace_review_received":
            let listingId = (userInfo["listing_id"] as? String).flatMap(UUID.init)
            let transactionId = (userInfo["transaction_id"] as? String).flatMap(UUID.init)
            let offerId = (userInfo["offer_id"] as? String).flatMap(UUID.init)
            let reviewId = (userInfo["review_id"] as? String).flatMap(UUID.init)
            pendingDestination = .marketplace(
                listingId: listingId,
                transactionId: transactionId,
                offerId: offerId,
                reviewId: reviewId
            )

        default:
            print("DeepLinkManager: Unknown notification type: \(type)")
        }
    }
}
