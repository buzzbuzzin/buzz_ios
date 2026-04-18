//
//  BookingConfigService.swift
//  Buzz
//
//  Service for fetching backend-managed booking configuration
//

import Foundation
import Supabase
import Combine

@MainActor
class BookingConfigService: ObservableObject {
    static let shared = BookingConfigService()
    private init() {}

    @Published var config: BookingConfig = .defaultConfig

    private let supabase = SupabaseClient.shared.client
    private var hasLoadedFromServer = false

    /// Reset to defaults on sign-out. Per-pilot booking config must not bleed into
    /// the next user on the same device.
    func resetForSignOut() {
        config = .defaultConfig
        hasLoadedFromServer = false
    }

    func fetchConfig() async {
        if DemoModeManager.shared.isDemoModeEnabled {
            config = .defaultConfig
            return
        }

        do {
            let response: BookingConfig = try await supabase
                .from("booking_config")
                .select()
                .eq("id", value: "default")
                .single()
                .execute()
                .value

            config = response
            hasLoadedFromServer = true
        } catch {
            print("BookingConfigService: Failed to fetch config, using defaults: \(error)")
            config = .defaultConfig
        }
    }

    func ensureConfigLoaded() async {
        guard !hasLoadedFromServer else { return }
        await fetchConfig()
    }
}
