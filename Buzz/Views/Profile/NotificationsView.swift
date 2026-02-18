//
//  NotificationsView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

struct NotificationsView: View {
    @StateObject private var notificationService = NotificationPreferencesService()
    @Environment(\.dismiss) var dismiss

    @State private var editingNotificationType: NotificationType? = nil

    enum NotificationType {
        // General
        case bookingReminders
        case bookingCancellations
        case weatherUpdates
        case receivedReviews
        case messages
        case tipReceived
        case payoutConfirmation
        // Beacon
        case beaconAccepted
        case beaconResolved
        // Hanger Talk
        case hangerTalkLikes
        case hangerTalkReplies
        case hangerTalkMentions
        case hangerTalkFollows
        case hangerTalkNewPosts
        // Marketplace
        case marketplaceOffers
        case marketplaceTransactions
        case marketplaceReviews
    }

    var body: some View {
        List {
            Section("General") {
                NotificationPreferenceCard(
                    title: "Booking Reminders",
                    description: "Reminders for upcoming bookings",
                    icon: "calendar",
                    options: notificationService.preferences.bookingReminders,
                    onEdit: {
                        editingNotificationType = .bookingReminders
                    }
                )

                NotificationPreferenceCard(
                    title: "Booking Cancellations",
                    description: "When a booking is cancelled",
                    icon: "calendar.badge.minus",
                    options: notificationService.preferences.bookingCancellations,
                    onEdit: {
                        editingNotificationType = .bookingCancellations
                    }
                )

                NotificationPreferenceCard(
                    title: "Weather Updates",
                    description: "Weather information for upcoming bookings",
                    icon: "cloud.sun",
                    options: notificationService.preferences.weatherUpdates,
                    onEdit: {
                        editingNotificationType = .weatherUpdates
                    }
                )

                NotificationPreferenceCard(
                    title: "Received Reviews",
                    description: "When you receive new reviews",
                    icon: "star.fill",
                    options: notificationService.preferences.receivedReviews,
                    onEdit: {
                        editingNotificationType = .receivedReviews
                    }
                )

                NotificationPreferenceCard(
                    title: "Messages",
                    description: "New messages from customers or pilots",
                    icon: "message.fill",
                    options: notificationService.preferences.messages,
                    onEdit: {
                        editingNotificationType = .messages
                    }
                )

                NotificationPreferenceCard(
                    title: "Tips Received",
                    description: "When a customer tips you",
                    icon: "dollarsign.circle.fill",
                    options: notificationService.preferences.tipReceived,
                    onEdit: {
                        editingNotificationType = .tipReceived
                    }
                )

                NotificationPreferenceCard(
                    title: "Payout Confirmation",
                    description: "When a payout is transferred to your account",
                    icon: "banknote.fill",
                    options: notificationService.preferences.payoutConfirmation,
                    onEdit: {
                        editingNotificationType = .payoutConfirmation
                    }
                )
            }

            Section("Beacon") {
                NotificationPreferenceCard(
                    title: "Volunteer Accepted",
                    description: "When a volunteer responds to your emergency",
                    icon: "figure.wave",
                    options: notificationService.preferences.beaconAccepted,
                    onEdit: {
                        editingNotificationType = .beaconAccepted
                    }
                )

                NotificationPreferenceCard(
                    title: "Mission Resolved",
                    description: "When an emergency mission is completed",
                    icon: "checkmark.shield.fill",
                    options: notificationService.preferences.beaconResolved,
                    onEdit: {
                        editingNotificationType = .beaconResolved
                    }
                )
            }

            Section("Hanger Talk") {
                NotificationPreferenceCard(
                    title: "New Posts",
                    description: "When someone you follow shares a post",
                    icon: "newspaper.fill",
                    options: notificationService.preferences.hangerTalkNewPosts,
                    onEdit: {
                        editingNotificationType = .hangerTalkNewPosts
                    }
                )

                NotificationPreferenceCard(
                    title: "Likes",
                    description: "When someone likes your post",
                    icon: "heart.fill",
                    options: notificationService.preferences.hangerTalkLikes,
                    onEdit: {
                        editingNotificationType = .hangerTalkLikes
                    }
                )

                NotificationPreferenceCard(
                    title: "Replies",
                    description: "When someone replies to your post",
                    icon: "arrowshape.turn.up.left.fill",
                    options: notificationService.preferences.hangerTalkReplies,
                    onEdit: {
                        editingNotificationType = .hangerTalkReplies
                    }
                )

                NotificationPreferenceCard(
                    title: "Mentions",
                    description: "When someone @mentions you",
                    icon: "at",
                    options: notificationService.preferences.hangerTalkMentions,
                    onEdit: {
                        editingNotificationType = .hangerTalkMentions
                    }
                )

                NotificationPreferenceCard(
                    title: "Follows",
                    description: "When someone follows you",
                    icon: "person.badge.plus",
                    options: notificationService.preferences.hangerTalkFollows,
                    onEdit: {
                        editingNotificationType = .hangerTalkFollows
                    }
                )
            }

            Section("Marketplace") {
                NotificationPreferenceCard(
                    title: "Offers",
                    description: "New offers and offer updates on your listings",
                    icon: "tag.fill",
                    options: notificationService.preferences.marketplaceOffers,
                    onEdit: {
                        editingNotificationType = .marketplaceOffers
                    }
                )

                NotificationPreferenceCard(
                    title: "Transactions",
                    description: "Purchases, shipping, and delivery updates",
                    icon: "shippingbox.fill",
                    options: notificationService.preferences.marketplaceTransactions,
                    onEdit: {
                        editingNotificationType = .marketplaceTransactions
                    }
                )

                NotificationPreferenceCard(
                    title: "Reviews",
                    description: "When you receive a marketplace review",
                    icon: "star.fill",
                    options: notificationService.preferences.marketplaceReviews,
                    onEdit: {
                        editingNotificationType = .marketplaceReviews
                    }
                )
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingNotificationType) { type in
            NotificationEditSheet(
                notificationType: type,
                preferences: $notificationService.preferences,
                onSave: {
                    savePreferences()
                }
            )
        }
        .onAppear {
            loadPreferences()
        }
    }

    private func loadPreferences() {
        notificationService.loadPreferences()
    }

    private func savePreferences() {
        notificationService.savePreferences()
    }
}

extension NotificationsView.NotificationType: Identifiable {
    var id: Self { self }
}

struct NotificationPreferenceCard: View {
    let title: String
    let description: String
    let icon: String
    let options: NotificationDeliveryOptions
    let onEdit: () -> Void

    var statusText: String {
        var enabled: [String] = []
        if options.system { enabled.append("Push notifications") }
        if options.email { enabled.append("Email") }
        if options.text { enabled.append("SMS") }

        if enabled.isEmpty {
            return "Off"
        } else {
            return "On: \(enabled.joined(separator: ", "))"
        }
    }

    var body: some View {
        Button(action: {
            onEdit()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NotificationEditSheet: View {
    let notificationType: NotificationsView.NotificationType
    @Binding var preferences: NotificationPreferences
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var localOptions: NotificationDeliveryOptions

    var title: String {
        switch notificationType {
        case .bookingReminders: return "Booking Reminders"
        case .bookingCancellations: return "Booking Cancellations"
        case .weatherUpdates: return "Weather Updates"
        case .receivedReviews: return "Received Reviews"
        case .messages: return "Messages"
        case .tipReceived: return "Tips Received"
        case .payoutConfirmation: return "Payout Confirmation"
        case .beaconAccepted: return "Volunteer Accepted"
        case .beaconResolved: return "Mission Resolved"
        case .hangerTalkLikes: return "Likes"
        case .hangerTalkReplies: return "Replies"
        case .hangerTalkMentions: return "Mentions"
        case .hangerTalkFollows: return "Follows"
        case .hangerTalkNewPosts: return "New Posts"
        case .marketplaceOffers: return "Offers"
        case .marketplaceTransactions: return "Transactions"
        case .marketplaceReviews: return "Reviews"
        }
    }

    var description: String {
        switch notificationType {
        case .bookingReminders: return "Reminders for upcoming bookings"
        case .bookingCancellations: return "When a booking is cancelled"
        case .weatherUpdates: return "Weather information for upcoming bookings"
        case .receivedReviews: return "When you receive new reviews"
        case .messages: return "New messages from customers or pilots"
        case .tipReceived: return "When a customer tips you"
        case .payoutConfirmation: return "When a payout is transferred to your account"
        case .beaconAccepted: return "When a volunteer responds to your emergency"
        case .beaconResolved: return "When an emergency mission is completed"
        case .hangerTalkLikes: return "When someone likes your post"
        case .hangerTalkReplies: return "When someone replies to your post"
        case .hangerTalkMentions: return "When someone @mentions you"
        case .hangerTalkFollows: return "When someone follows you"
        case .hangerTalkNewPosts: return "When someone you follow shares a post"
        case .marketplaceOffers: return "New offers and offer updates on your listings"
        case .marketplaceTransactions: return "Purchases, shipping, and delivery updates"
        case .marketplaceReviews: return "When you receive a marketplace review"
        }
    }

    var bindingOptions: Binding<NotificationDeliveryOptions> {
        switch notificationType {
        case .bookingReminders: return $preferences.bookingReminders
        case .bookingCancellations: return $preferences.bookingCancellations
        case .weatherUpdates: return $preferences.weatherUpdates
        case .receivedReviews: return $preferences.receivedReviews
        case .messages: return $preferences.messages
        case .tipReceived: return $preferences.tipReceived
        case .payoutConfirmation: return $preferences.payoutConfirmation
        case .beaconAccepted: return $preferences.beaconAccepted
        case .beaconResolved: return $preferences.beaconResolved
        case .hangerTalkLikes: return $preferences.hangerTalkLikes
        case .hangerTalkReplies: return $preferences.hangerTalkReplies
        case .hangerTalkMentions: return $preferences.hangerTalkMentions
        case .hangerTalkFollows: return $preferences.hangerTalkFollows
        case .hangerTalkNewPosts: return $preferences.hangerTalkNewPosts
        case .marketplaceOffers: return $preferences.marketplaceOffers
        case .marketplaceTransactions: return $preferences.marketplaceTransactions
        case .marketplaceReviews: return $preferences.marketplaceReviews
        }
    }

    init(notificationType: NotificationsView.NotificationType, preferences: Binding<NotificationPreferences>, onSave: @escaping () -> Void) {
        self.notificationType = notificationType
        self._preferences = preferences
        self.onSave = onSave

        // Initialize local options with current value
        switch notificationType {
        case .bookingReminders:
            _localOptions = State(initialValue: preferences.wrappedValue.bookingReminders)
        case .bookingCancellations:
            _localOptions = State(initialValue: preferences.wrappedValue.bookingCancellations)
        case .weatherUpdates:
            _localOptions = State(initialValue: preferences.wrappedValue.weatherUpdates)
        case .receivedReviews:
            _localOptions = State(initialValue: preferences.wrappedValue.receivedReviews)
        case .messages:
            _localOptions = State(initialValue: preferences.wrappedValue.messages)
        case .tipReceived:
            _localOptions = State(initialValue: preferences.wrappedValue.tipReceived)
        case .payoutConfirmation:
            _localOptions = State(initialValue: preferences.wrappedValue.payoutConfirmation)
        case .beaconAccepted:
            _localOptions = State(initialValue: preferences.wrappedValue.beaconAccepted)
        case .beaconResolved:
            _localOptions = State(initialValue: preferences.wrappedValue.beaconResolved)
        case .hangerTalkLikes:
            _localOptions = State(initialValue: preferences.wrappedValue.hangerTalkLikes)
        case .hangerTalkReplies:
            _localOptions = State(initialValue: preferences.wrappedValue.hangerTalkReplies)
        case .hangerTalkMentions:
            _localOptions = State(initialValue: preferences.wrappedValue.hangerTalkMentions)
        case .hangerTalkFollows:
            _localOptions = State(initialValue: preferences.wrappedValue.hangerTalkFollows)
        case .hangerTalkNewPosts:
            _localOptions = State(initialValue: preferences.wrappedValue.hangerTalkNewPosts)
        case .marketplaceOffers:
            _localOptions = State(initialValue: preferences.wrappedValue.marketplaceOffers)
        case .marketplaceTransactions:
            _localOptions = State(initialValue: preferences.wrappedValue.marketplaceTransactions)
        case .marketplaceReviews:
            _localOptions = State(initialValue: preferences.wrappedValue.marketplaceReviews)
        }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)

                // Description
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Toggles
                VStack(spacing: 20) {
                    Toggle(isOn: $localOptions.system) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                            Text("Push notifications")
                        }
                    }

                    Toggle(isOn: $localOptions.email) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text("Email")
                        }
                    }

                    Toggle(isOn: $localOptions.text) {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(.blue)
                            Text("SMS")
                        }
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Update the binding with local changes
                        bindingOptions.wrappedValue = localOptions
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
