//
//  WelcomeView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showAuthenticationView = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.blue.opacity(0.4),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main Content
                VStack(spacing: 32) {
                    // Logo
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    // Welcome Message
                    VStack(spacing: 16) {
                        Text("Your journey with")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.white)
                        
                        Text("drones begins here")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                
                Spacer()
                
                // Get Started Button
                VStack(spacing: 16) {
                    Button(action: {
                        showAuthenticationView = true
                    }) {
                        HStack {
                            Text("Get Started")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
        .fullScreenCover(isPresented: $showAuthenticationView) {
            AuthenticationView()
                .environmentObject(authService)
        }
    }
}

