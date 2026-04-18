//
//  NWSAlertService.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/11/26.
//

import Foundation
import BackgroundTasks
import CoreLocation
import Combine

@MainActor
class NWSAlertService: ObservableObject {
    static let shared = NWSAlertService()

    @Published var activeAlerts: [NWSAlertFeature] = []
    @Published var lastAlertCheckTime: Date?
    @Published var isLoading = false

    private let baseURL = "https://api.weather.gov"
    private let notificationManager = NotificationManager.shared
    private let notificationPreferencesService = NotificationPreferencesService()

    /// Clear in-memory alert cache on sign-out so a new user on the same device does
    /// not briefly see the previous user's alerts before the next fetch completes.
    func resetForSignOut() {
        activeAlerts = []
        lastAlertCheckTime = nil
        isLoading = false
    }

    private static let seenAlertIDsKey = "nws_seen_alert_ids"
    private static let lastAlertNotificationTimeKey = "nws_last_alert_notification_time"
    static let backgroundTaskIdentifier = "com.buzz.app.ios.nws-alert-check"

    private init() {}

    // MARK: - Fetch Alerts

    func fetchActiveAlerts(latitude: Double, longitude: Double) async throws -> [NWSAlertFeature] {
        let urlString = "\(baseURL)/alerts/active?point=\(latitude),\(longitude)"
        guard let url = URL(string: urlString) else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Buzz/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        let alertResponse = try JSONDecoder().decode(NWSAlertResponse.self, from: data)

        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        let filtered = alertResponse.features.filter { feature in
            guard let expiresString = feature.properties.expires else { return true }
            if let expires = isoFormatter.date(from: expiresString) ?? fallbackFormatter.date(from: expiresString) {
                return expires > now
            }
            return true
        }

        let severityOrder = ["Extreme": 0, "Severe": 1, "Moderate": 2, "Minor": 3, "Unknown": 4]
        return filtered.sorted { a, b in
            let aOrder = severityOrder[a.properties.severity] ?? 4
            let bOrder = severityOrder[b.properties.severity] ?? 4
            return aOrder < bOrder
        }
    }

    // MARK: - Check and Notify

    func checkForNewAlerts(latitude: Double, longitude: Double, pilotId: UUID) async {
        if DemoModeManager.shared.isDemoModeEnabled {
            activeAlerts = demoAlerts()
            lastAlertCheckTime = Date()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let alerts = try await fetchActiveAlerts(latitude: latitude, longitude: longitude)
            activeAlerts = alerts
            lastAlertCheckTime = Date()

            let seenIds = getSeenAlertIDs()
            let newAlerts = alerts.filter { !seenIds.contains($0.id) }

            guard !newAlerts.isEmpty else { return }

            try await notificationPreferencesService.loadPreferences(userId: pilotId)
            guard notificationPreferencesService.preferences.weatherUpdates.system else { return }
            guard canSendNotification() else { return }

            for alert in newAlerts.prefix(3) {
                await notificationManager.notifyWeatherAlert(
                    alertId: alert.id,
                    event: alert.properties.event,
                    headline: alert.properties.headline,
                    severity: alert.properties.severity,
                    areaDesc: alert.properties.areaDesc
                )
                markAlertAsSeen(alert.id)
            }

            updateLastNotificationTime()
            pruneOldSeenAlerts()
        } catch {
            print("NWSAlertService: Failed to check for alerts: \(error)")
        }
    }

    // MARK: - Background Task

    func scheduleBackgroundAlertCheck() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("NWSAlertService: Failed to schedule background task: \(error)")
        }
    }

    func handleBackgroundAlertCheck(task: BGAppRefreshTask) async {
        scheduleBackgroundAlertCheck()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        let location = LocationTrackingService.shared.lastKnownLocation
            ?? LocationHelper.shared.getCurrentLocation()

        guard let location else {
            task.setTaskCompleted(success: true)
            return
        }

        await performBackgroundCheck(latitude: location.latitude, longitude: location.longitude)
        task.setTaskCompleted(success: true)
    }

    private func performBackgroundCheck(latitude: Double, longitude: Double) async {
        // Re-read preferences from disk — the singleton's in-memory copy can be stale
        // if the user toggled the preference while the app was backgrounded.
        notificationPreferencesService.loadPreferences()
        guard notificationPreferencesService.preferences.weatherUpdates.system else { return }
        guard canSendNotification() else { return }

        do {
            let alerts = try await fetchActiveAlerts(latitude: latitude, longitude: longitude)
            let seenIds = getSeenAlertIDs()
            let newAlerts = alerts.filter { !seenIds.contains($0.id) }

            for alert in newAlerts.prefix(3) {
                await notificationManager.notifyWeatherAlert(
                    alertId: alert.id,
                    event: alert.properties.event,
                    headline: alert.properties.headline,
                    severity: alert.properties.severity,
                    areaDesc: alert.properties.areaDesc
                )
                markAlertAsSeen(alert.id)
            }

            if !newAlerts.isEmpty {
                updateLastNotificationTime()
            }

            pruneOldSeenAlerts()
        } catch {
            print("NWSAlertService: Background check failed: \(error)")
        }
    }

    // MARK: - Seen Alert Tracking

    private func getSeenAlertIDs() -> Set<String> {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.seenAlertIDsKey) as? [String: Double] else {
            return []
        }
        return Set(dict.keys)
    }

    private func markAlertAsSeen(_ alertId: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: Self.seenAlertIDsKey) as? [String: Double]) ?? [:]
        dict[alertId] = Date().timeIntervalSince1970
        UserDefaults.standard.set(dict, forKey: Self.seenAlertIDsKey)
    }

    private func pruneOldSeenAlerts() {
        guard var dict = UserDefaults.standard.dictionary(forKey: Self.seenAlertIDsKey) as? [String: Double] else { return }
        let cutoff = Date().timeIntervalSince1970 - (48 * 3600)
        dict = dict.filter { $0.value > cutoff }
        UserDefaults.standard.set(dict, forKey: Self.seenAlertIDsKey)
    }

    // MARK: - Rate Limiting

    private func canSendNotification() -> Bool {
        guard let lastTime = UserDefaults.standard.object(forKey: Self.lastAlertNotificationTimeKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastTime) >= 3600
    }

    private func updateLastNotificationTime() {
        UserDefaults.standard.set(Date(), forKey: Self.lastAlertNotificationTimeKey)
    }

    // MARK: - Demo Mode

    private func demoAlerts() -> [NWSAlertFeature] {
        [
            NWSAlertFeature(
                id: "demo-alert-1",
                properties: NWSAlertProperties(
                    event: "Severe Thunderstorm Warning",
                    severity: "Severe",
                    urgency: "Immediate",
                    headline: "Severe Thunderstorm Warning issued for your area until 6:00 PM",
                    description: "A severe thunderstorm was located near the airport, moving northeast at 30 mph. Hail up to 1 inch and wind gusts up to 60 mph are possible.",
                    instruction: "Move to an interior room on the lowest floor of a building. Avoid windows.",
                    onset: ISO8601DateFormatter().string(from: Date()),
                    expires: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
                    areaDesc: "Tompkins County, NY"
                )
            ),
            NWSAlertFeature(
                id: "demo-alert-2",
                properties: NWSAlertProperties(
                    event: "Wind Advisory",
                    severity: "Minor",
                    urgency: "Expected",
                    headline: "Wind Advisory in effect from 2:00 PM to 10:00 PM",
                    description: "Southwest winds 25 to 35 mph with gusts up to 55 mph expected.",
                    instruction: "Secure outdoor objects. Use caution when driving.",
                    onset: ISO8601DateFormatter().string(from: Date()),
                    expires: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7200)),
                    areaDesc: "Tompkins County, NY"
                )
            )
        ]
    }
}
