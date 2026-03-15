//
//  UpdatePopupView.swift
//  Buzz
//
//  Created by AI Assistant on 01/20/26.
//

import SwiftUI

struct UpdatePopupView: View {
    @ObservedObject var updateService: AppUpdateService
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Don't dismiss on background tap for better UX
                }

            // Popup content
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
                    .padding(.top, 10)

                // Title
                Text("Update Available")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // Message
                Text("A newer version of Buzz is available on the App Store. Update now to get the latest features and improvements!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .lineSpacing(4)

                // Version info (if available)
                if let latestVersion = updateService.latestVersion {
                    Text("Latest version: \(latestVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }

                Spacer(minLength: 20)

                // Buttons
                VStack(spacing: 12) {
                    // Update button
                    Button(action: {
                        updateService.openAppStore()
                        isPresented = false
                    }) {
                        Text("Update Now")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }

                    // Dismiss button
                    Button(action: {
                        updateService.dismissUpdate()
                        isPresented = false
                    }) {
                        Text("Maybe Later")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 320)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Update available popup")
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}

#Preview {
    let updateService = AppUpdateService()
    updateService.isUpdateAvailable = true
    updateService.latestVersion = "2.1.0"

    return ZStack {
        Color.gray.opacity(0.3)
            .edgesIgnoringSafeArea(.all)

        UpdatePopupView(updateService: updateService, isPresented: .constant(true))
    }
}