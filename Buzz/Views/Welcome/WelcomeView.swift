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
    @State private var logoTextOffset: CGFloat = 0
    @State private var logoTextOpacity: Double = 1.0
    @State private var logoOffset: CGFloat = 0
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width
    
    var body: some View {
        ZStack {
            // Background color
            Color(red: 0x28 / 255.0, green: 0x2C / 255.0, blue: 0x35 / 255.0)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Main Content - centered horizontally
                    HStack {
                        Spacer()
                        ZStack {
                            // Logo_text - starts at center, moves right and disappears
                            Image("Logo_text")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .offset(x: logoTextOffset)
                                .opacity(logoTextOpacity)
                            
                            // Buzz Logo - slides in from left after Logo_text disappears
                            Image("Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                .offset(x: logoOffset)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                }
                .onAppear {
                    screenWidth = geometry.size.width
                }
            }
        }
        .onAppear {
            // Logo_text starts at center (offset = 0)
            logoTextOffset = 0
            logoTextOpacity = 1.0
            
            // Start buzz_logo off-screen to the left
            logoOffset = -screenWidth / 2 - 75 // Off-screen left (half screen + half logo width)
            
            // Small delay to ensure geometry is ready, then start animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Wait 0.5 seconds, then animate Logo_text to move right and fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeIn(duration: 0.8)) {
                        logoTextOffset = screenWidth / 2 + 75 // Off-screen right
                        logoTextOpacity = 0.0 // Fade out
                    }
                }
                
                // Then: After Logo_text animation completes (0.5 + 0.8 = 1.3 seconds), slide buzz_logo in from left
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        logoOffset = 0 // Center position
                    }
                }
                
                // After buzz_logo reaches center (1.3 + 1.0 = 2.3 seconds), wait 0.5 seconds, then navigate to AuthenticationView
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    showAuthenticationView = true
                }
            }
        }
        .fullScreenCover(isPresented: $showAuthenticationView) {
            AuthenticationView()
                .environmentObject(authService)
        }
    }
}

