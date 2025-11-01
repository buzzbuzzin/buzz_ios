//
//  BuzzApp.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI
import GoogleSignIn

@main
struct BuzzApp: App {
    @StateObject private var authService = AuthService()
    @AppStorage("appearanceMode") private var appearanceModeString: String = "system"

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
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
            .onOpenURL { url in
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
