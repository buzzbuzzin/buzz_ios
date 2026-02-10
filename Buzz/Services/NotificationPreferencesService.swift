//
//  NotificationPreferencesService.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import Foundation
import Combine

@MainActor
class NotificationPreferencesService: ObservableObject {
    @Published var preferences: NotificationPreferences
    @Published var isLoading = false
    @Published var errorMessage: String?

    private static let storageKey = "notification_preferences"

    init() {
        // Load from UserDefaults on init, or use defaults
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.preferences = saved
        } else {
            self.preferences = NotificationPreferences()
        }
    }

    func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = NotificationPreferences()
        }
    }

    /// Protocol conformance — userId is unused since preferences are stored locally.
    func loadPreferences(userId: UUID) async throws {
        loadPreferences()
    }

    func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
