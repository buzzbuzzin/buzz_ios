//
//  AppUpdateService.swift
//  Buzz
//
//  Created by AI Assistant on 01/20/26.
//

import Foundation
import Combine
import UIKit

/// Service for checking app updates from the App Store
@MainActor
class AppUpdateService: ObservableObject {
    @Published var isUpdateAvailable = false
    @Published var latestVersion: String?
    @Published var isCheckingForUpdate = false

    private let bundleID = Config.appStoreBundleID
    private let lookupURL = "https://itunes.apple.com/lookup"
    private var appStoreTrackId: Int?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Check for updates when service is initialized
        Task {
            await checkForUpdate()
        }
    }

    /// Check if there's a newer version available on the App Store
    func checkForUpdate() async {
        guard !isCheckingForUpdate else { return }

        isCheckingForUpdate = true
        defer { isCheckingForUpdate = false }

        do {
            let updateInfo = try await fetchAppStoreVersion()
            let currentVersion = getCurrentAppVersion()

            // Store the track ID for App Store URL
            appStoreTrackId = updateInfo.trackId

            if let appStoreVersion = updateInfo.version,
               isVersionNewer(appStoreVersion, than: currentVersion) {
                isUpdateAvailable = true
                latestVersion = appStoreVersion
            } else {
                isUpdateAvailable = false
                latestVersion = nil
            }
        } catch {
            print("Failed to check for app update: \(error.localizedDescription)")
            // Don't show update available on error to avoid false positives
            isUpdateAvailable = false
            latestVersion = nil
        }
    }

    /// Open the App Store page for this app
    func openAppStore() {
        guard let trackId = appStoreTrackId else {
            print("App Store track ID not available")
            return
        }
        let appStoreURL = "https://apps.apple.com/app/id\(trackId)"
        if let url = URL(string: appStoreURL),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    /// Dismiss the update notification (user can still be reminded later)
    func dismissUpdate() {
        isUpdateAvailable = false
    }

    // MARK: - Private Methods

    private func fetchAppStoreVersion() async throws -> AppStoreUpdateInfo {
        guard var urlComponents = URLComponents(string: lookupURL) else {
            throw AppUpdateError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "US")
        ]

        guard let url = urlComponents.url else {
            throw AppUpdateError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppUpdateError.networkError
        }

        let decoder = JSONDecoder()
        let lookupResponse = try decoder.decode(AppStoreLookupResponse.self, from: data)

        guard let result = lookupResponse.results.first else {
            throw AppUpdateError.appNotFound
        }

        return AppStoreUpdateInfo(version: result.version, trackId: result.trackId)
    }

    private func getCurrentAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func isVersionNewer(_ newVersion: String, than currentVersion: String) -> Bool {
        let newComponents = newVersion.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(newComponents.count, currentComponents.count)

        for i in 0..<maxLength {
            let new = i < newComponents.count ? newComponents[i] : 0
            let current = i < currentComponents.count ? currentComponents[i] : 0

            if new > current {
                return true
            } else if new < current {
                return false
            }
        }

        return false // versions are equal
    }
}

// MARK: - Supporting Types

private struct AppStoreLookupResponse: Codable {
    let results: [AppStoreResult]
}

private struct AppStoreResult: Codable {
    let version: String
    let trackId: Int
}

private struct AppStoreUpdateInfo {
    let version: String?
    let trackId: Int?
}

private enum AppUpdateError: Error {
    case invalidURL
    case networkError
    case appNotFound
    case decodingError
}