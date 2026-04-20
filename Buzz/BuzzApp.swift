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

enum AppRootDestination: Equatable {
    case launch
    case welcome
    case verificationLoading
    case verificationNetworkError
    case onboarding
    case main
}

func appRootDestination(
    hasResolvedInitialSession: Bool,
    isAuthenticated: Bool,
    shouldDelayNavigation: Bool,
    verificationState: VerificationGateState
) -> AppRootDestination {
    guard hasResolvedInitialSession else {
        return .launch
    }

    guard isAuthenticated && !shouldDelayNavigation else {
        return .welcome
    }

    switch verificationState {
    case .loading:
        return .verificationLoading
    case .verified:
        return .main
    case .unverified:
        return .onboarding
    case .networkError:
        return .verificationNetworkError
    }
}

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
    
    /// Handle remote notification received while app is in foreground or background.
    /// iOS tracks `.newData` vs `.noData` / `.failed` reports to decide how much
    /// background-fetch budget to grant in the future — always returning `.noData`
    /// immediately wastes silent-push opportunities. Currently Buzz only sends alert
    /// pushes (no content-available), but route through a handler so we can distinguish
    /// silent vs alert pushes and let the NotificationManager refresh relevant state.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Give ourselves a short window to do any payload-driven work. If nothing
        // actionable is in the payload we still report `.noData` honestly.
        let aps = userInfo["aps"] as? [AnyHashable: Any]
        let isSilentPush = (aps?["content-available"] as? Int) == 1
        Task { @MainActor in
            // For both alert and silent pushes, refresh device-token bookkeeping so
            // a token rotation (if any) can reach the backend. This is cheap and safe.
            await NotificationManager.shared.syncDeviceTokenIfNeeded()
            completionHandler(isSilentPush ? .newData : .noData)
        }
    }
}

@main
struct BuzzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var verificationGate = VerificationGate()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var locationTrackingService = LocationTrackingService.shared
    @StateObject private var updateService = AppUpdateService()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @AppStorage("appearanceMode") private var appearanceModeString: String = "system"
    @State private var showUpdatePopup = false
    @Environment(\.scenePhase) private var scenePhase
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
        
        // Demo mode is now controlled solely by launch arguments (DEMO_MODE or UI_TESTING)
        // via DemoModeManager — no UserDefaults persistence
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    switch appRootDestination(
                        hasResolvedInitialSession: authService.hasResolvedInitialSession,
                        isAuthenticated: authService.isAuthenticated,
                        shouldDelayNavigation: authService.shouldDelayNavigation,
                        verificationState: verificationGate.state
                    ) {
                    case .launch:
                        LaunchScreenView()
                            .transition(.opacity)
                    case .verificationLoading:
                        LoadingView(message: "Checking verification…")
                            .transition(.opacity)
                    case .verificationNetworkError:
                        VerificationNetworkErrorView(verificationGate: verificationGate)
                            .environmentObject(authService)
                            .transition(.opacity)
                    case .main:
                        MainTabView()
                            .environmentObject(authService)
                            .transition(.opacity)
                    case .onboarding:
                        OnboardingVerificationView(verificationGate: verificationGate)
                            .environmentObject(authService)
                            .transition(.opacity)
                    case .welcome:
                        WelcomeView()
                            .environmentObject(authService)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
                .animation(.easeInOut(duration: 0.3), value: verificationGate.state)
                .preferredColorScheme(colorScheme)

                // Update popup overlay
                if showUpdatePopup {
                    UpdatePopupView(updateService: updateService, isPresented: $showUpdatePopup)
                }

                EmergencyFlashOverlay()

                if !networkMonitor.isConnected {
                    VStack {
                        NoConnectionBannerView()
                            .padding(.top, 50)
                        Spacer()
                    }
                    .zIndex(999)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
            .onChange(of: updateService.isUpdateAvailable) { _, isAvailable in
                if isAvailable {
                    showUpdatePopup = true
                }
            }
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                primeVerificationGate()

                // Update location and track app version whenever authentication status changes
                if isAuthenticated, let userId = authService.activeUserId {
                    Task {
                        await notificationManager.syncDeviceTokenIfNeeded()
                        do {
                            try await locationTrackingService.updateUserLocation(userId: userId)
                        } catch {
                            print("Failed to update user location on auth change: \(error.localizedDescription)")
                        }
                    }
                    AppVersionTrackingService.shared.trackAppVersion(userId: userId)
                    Task { await verificationGate.refresh(userId: userId) }
                }
            }
            .onChange(of: authService.shouldDelayNavigation) { _, isDelaying in
                if !isDelaying, authService.isAuthenticated {
                    primeVerificationGate()
                    Task { await verificationGate.refresh(userId: authService.activeUserId) }
                }
            }
            .onChange(of: networkMonitor.isConnected) { _, isConnected in
                guard isConnected,
                      authService.isAuthenticated,
                      verificationGate.state == .networkError else { return }
                Task { await verificationGate.retry(userId: authService.activeUserId) }
            }
            .onAppear {
                primeVerificationGate()
                if authService.isAuthenticated {
                    Task { await verificationGate.refresh(userId: authService.activeUserId) }
                }

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
                        await notificationManager.syncDeviceTokenIfNeeded()
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
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active,
                      authService.isAuthenticated,
                      let userId = authService.activeUserId else { return }
                AppVersionTrackingService.shared.trackAppVersion(userId: userId)
                Task {
                    do {
                        try await locationTrackingService.updateUserLocation(userId: userId)
                    } catch {
                        print("Failed to update user location on scene activation: \(error.localizedDescription)")
                    }
                }
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

    private func primeVerificationGate() {
        let userId = authService.isAuthenticated ? authService.activeUserId : nil
        verificationGate.prime(userId: userId)
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
