//
//  FlightPackagesView.swift
//  Buzz
//
//  Created for displaying both Buzz Auto and Buzz Real Estate packages in full-screen
//

import SwiftUI

struct FlightPackagesView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                        
                        Text("Buzz Subscription")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose from our premium packages designed to make your booking experience easier and more affordable.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Package Cards
                    VStack(spacing: 16) {
                        // Buzz Auto Card
                        NavigationLink(destination: FlightPackageView()) {
                            PackageCard(
                                icon: "car.circle.fill",
                                title: "Buzz Auto",
                                description: "Perfect for car dealerships. Get up to 50 cinematic videos per month with dedicated drone & pilot access.",
                                color: .blue
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Buzz Real Estate Card
                        NavigationLink(destination: RealEstatePackageView()) {
                            PackageCard(
                                icon: "house.circle.fill",
                                title: "Buzz Real Estate",
                                description: "At Buzz, our pilots have a passion for creating inspiring content. Our advanced licensed drone pilots and camera operators are dedicated to capturing quality content for your real estate business.",
                                color: .purple
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Flight Packages")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Package Card

struct PackageCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Easier booking")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Better pricing")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Premium service")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
    }
}

