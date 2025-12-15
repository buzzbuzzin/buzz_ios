//
//  BuzzApp.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import GoogleSignIn
import StripePaymentSheet
import UserNotifications

// MARK: - AppDelegate for Remote Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }
    
    /// Called when APNs successfully registers the device
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }
    
    /// Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
    
    /// Handle remote notification received while app is in foreground or background
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("HandleRemoteNotification"),
            object: nil,
            userInfo: userInfo
        )
        completionHandler(.newData)
    }
}

@main
struct BuzzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("appearanceMode") private var appearanceModeString: String = "system"
    private let isUITestMode = ProcessInfo.processInfo.arguments.contains("UI_TESTING") || ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"

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
        
        // Enable demo mode during UI tests to avoid network calls
        if isUITestMode {
            DemoModeManager.shared.isDemoModeEnabled = true
            UserDefaults.standard.set(true, forKey: "demoModeEnabled")
        }
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
                
                // Request notification permissions and register for remote notifications
                Task {
                    await notificationManager.updateAuthorizationStatus()
                    
                    // Request permission if not yet determined
                    if notificationManager.authorizationStatus == .notDetermined {
                        let granted = await notificationManager.requestAuthorization()
                        if granted {
                            // Register for APNs push notifications
                            notificationManager.registerForRemoteNotifications()
                        }
                    } else if notificationManager.authorizationStatus == .authorized {
                        // Already authorized, register for remote notifications
                        notificationManager.registerForRemoteNotifications()
                    }
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
