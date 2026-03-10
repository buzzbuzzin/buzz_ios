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
import BackgroundTasks

// MARK: - AppDelegate for Remote Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register NWS weather alert background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: NWSAlertService.backgroundTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await NWSAlertService.shared.handleBackgroundAlertCheck(task: task as! BGAppRefreshTask)
            }
        }
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
        completionHandler(.noData)
    }
}

@main
struct BuzzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var locationTrackingService = LocationTrackingService.shared
    @StateObject private var updateService = AppUpdateService()
    @AppStorage("appearanceMode") private var appearanceModeString: String = "system"
    @State private var showUpdatePopup = false
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
            ZStack {
                Group {
                    if !authService.hasResolvedInitialSession {
                        LaunchScreenView()
                            .transition(.opacity)
                    } else if authService.isAuthenticated && !authService.shouldDelayNavigation {
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

                // Update popup overlay
                if showUpdatePopup {
                    UpdatePopupView(updateService: updateService, isPresented: $showUpdatePopup)
                }

                EmergencyFlashOverlay()
            }
            .onChange(of: updateService.isUpdateAvailable) { _, isAvailable in
                if isAvailable {
                    showUpdatePopup = true
                }
            }
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                // Update location and track app version whenever authentication status changes
                if isAuthenticated, let userId = authService.activeUserId {
                    Task {
                        do {
                            try await locationTrackingService.updateUserLocation(userId: userId)
                        } catch {
                            print("Failed to update user location on auth change: \(error.localizedDescription)")
                        }
                    }
                    AppVersionTrackingService.shared.trackAppVersion(userId: userId)
                }
            }
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

                    // Update user location and track app version if authenticated
                    if authService.isAuthenticated, let userId = authService.activeUserId {
                        do {
                            try await locationTrackingService.updateUserLocation(userId: userId)
                        } catch {
                            print("Failed to update user location: \(error.localizedDescription)")
                        }
                        AppVersionTrackingService.shared.trackAppVersion(userId: userId)
                    }

                    // Check for app updates after a short delay to avoid blocking app launch
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await updateService.checkForUpdate()

                    // Schedule NWS weather alert background checks
                    NWSAlertService.shared.scheduleBackgroundAlertCheck()
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

private struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(red: 0x28 / 255.0, green: 0x2C / 255.0, blue: 0x35 / 255.0)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                ProgressView()
                    .tint(.white)
            }
        }
    }
}
