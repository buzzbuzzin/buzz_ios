//
//  BuzzApp.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import GoogleSignIn
import StripePaymentSheet

@main
struct BuzzApp: App {
    @StateObject private var authService = AuthService()
    @AppStorage("appearanceMode") private var appearanceModeString: String = "system"

    init() {
        // Configure Google Sign In
        // The client ID can be set in Info.plist as GIDClientID, or configured here
        // If set in Info.plist, this configuration is optional but recommended
        if Config.googleClientID != "YOUR_GOOGLE_CLIENT_ID" {
            let config = GIDConfiguration(clientID: Config.googleClientID)
            GIDSignIn.sharedInstance.configuration = config
        }
        
        // Configure Stripe
        StripeAPI.defaultPublishableKey = Config.stripePublishableKey
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated && !authService.shouldDelayNavigation {
                    MainTabView()
                        .environmentObject(authService)
                        .transition(.opacity)
                } else {
                    WelcomeView()
                        .environmentObject(authService)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
            .preferredColorScheme(colorScheme)
            .onAppear {
                // Attempt to restore the user's sign-in state
                // Reference: https://developers.google.com/identity/sign-in/ios/sign-in#swift
                GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                    // Note: We handle authentication through AuthService,
                    // so we don't need to update UI here directly
                    // The AuthService will check authentication status separately
                }
            }
            .onOpenURL { url in
                // Handle the authentication redirect URL
                // Reference: https://developers.google.com/identity/sign-in/ios/sign-in#swift
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch appearanceModeString {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // system
        }
    }
}
