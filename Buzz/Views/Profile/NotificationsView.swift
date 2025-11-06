//
//  NotificationsView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct NotificationsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var notificationService = NotificationPreferencesService()
    @Environment(\.dismiss) var dismiss
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var editingNotificationType: NotificationType? = nil
    
    enum NotificationType {
        case bookingReminders
        case weatherUpdates
        case receivedReviews
        case rankImprovements
        case bookingUpdates
        case messages
    }
    
    var body: some View {
        List {
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
                title: "Rank Improvements",
                description: "When your rank or tier improves",
                icon: "chart.line.uptrend.xyaxis",
                options: notificationService.preferences.rankImprovements,
                onEdit: {
                    editingNotificationType = .rankImprovements
                }
            )
            
            NotificationPreferenceCard(
                title: "Booking Updates",
                description: "Updates on your booking status",
                icon: "bell.badge",
                options: notificationService.preferences.bookingUpdates,
                onEdit: {
                    editingNotificationType = .bookingUpdates
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
        .task {
            await loadPreferences()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {}
        } message: {
            Text("Notification preferences saved successfully")
        }
    }
    
    private func loadPreferences() async {
        guard let currentUser = authService.currentUser else { return }
        try? await notificationService.loadPreferences(userId: currentUser.id)
    }
    
    private func savePreferences() {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            do {
                try await notificationService.savePreferences(userId: currentUser.id)
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
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
        case .weatherUpdates: return "Weather Updates"
        case .receivedReviews: return "Received Reviews"
        case .rankImprovements: return "Rank Improvements"
        case .bookingUpdates: return "Booking Updates"
        case .messages: return "Messages"
        }
    }
    
    var description: String {
        switch notificationType {
        case .bookingReminders: return "Reminders for upcoming bookings"
        case .weatherUpdates: return "Weather information for upcoming bookings"
        case .receivedReviews: return "When you receive new reviews"
        case .rankImprovements: return "When your rank or tier improves"
        case .bookingUpdates: return "Updates on your booking status"
        case .messages: return "New messages from customers or pilots"
        }
    }
    
    var bindingOptions: Binding<NotificationDeliveryOptions> {
        switch notificationType {
        case .bookingReminders: return $preferences.bookingReminders
        case .weatherUpdates: return $preferences.weatherUpdates
        case .receivedReviews: return $preferences.receivedReviews
        case .rankImprovements: return $preferences.rankImprovements
        case .bookingUpdates: return $preferences.bookingUpdates
        case .messages: return $preferences.messages
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
        case .weatherUpdates:
            _localOptions = State(initialValue: preferences.wrappedValue.weatherUpdates)
        case .receivedReviews:
            _localOptions = State(initialValue: preferences.wrappedValue.receivedReviews)
        case .rankImprovements:
            _localOptions = State(initialValue: preferences.wrappedValue.rankImprovements)
        case .bookingUpdates:
            _localOptions = State(initialValue: preferences.wrappedValue.bookingUpdates)
        case .messages:
            _localOptions = State(initialValue: preferences.wrappedValue.messages)
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

