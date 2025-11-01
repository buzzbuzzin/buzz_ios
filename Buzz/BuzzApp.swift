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
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .environmentObject(authService)
                        .transition(.opacity)
                } else {
                    AuthenticationView()
                        .environmentObject(authService)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
