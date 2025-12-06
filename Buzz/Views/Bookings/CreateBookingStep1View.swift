//
//  CreateBookingStep1View.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import MapKit

struct CreateBookingStep1View: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var selectedDate: Date
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var selectedSpecialization: BookingSpecialization?
    @Binding var requiredMinimumRank: Int
    
    @State private var showLocationSearch = false
    @State private var showRankInfo = false
    @State private var showIndustryWarning = false
    @State private var showLocationWarning = false
    
    // Supported industries
    private let supportedIndustries: [BookingSpecialization] = [.automotive, .realEstate]
    
    // Ithaca NY coordinates (center of service area)
    private let ithacaNY = CLLocationCoordinate2D(latitude: 42.4434, longitude: -76.5017)
    private let serviceRadiusMiles: Double = 100.0
    
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Location Section
                SectionCard(number: 1, title: "Location") {
                    Button(action: {
                        showLocationSearch = true
                    }) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 24))
                            
                            Text(locationName.isEmpty ? "Where to?" : locationName)
                                .foregroundColor(locationName.isEmpty ? .secondary : .primary)
                                .font(.body)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Date & Time Section
                SectionCard(number: 2, title: "Date & Time") {
                    VStack(spacing: 12) {
                        // Date picker button
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.red)
                                .font(.system(size: 20))
                            
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Time picker button
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.red)
                                .font(.system(size: 20))
                            
                            DatePicker(
                                "",
                                selection: $startTime,
                                displayedComponents: [.hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Warning message for specific industries
                        if selectedSpecialization == .automotive {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                                Text("Start time must be before noon")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Pilot Rank Section
                SectionCard(number: 3, title: "Pilot Rank") {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 20))
                            
                            Picker("Minimum Rank", selection: $requiredMinimumRank) {
                                ForEach(0...4, id: \.self) { rank in
                                    Text(PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: rank).tierName)
                                        .tag(rank)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        Text("Pricing varies by rank")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // Specialization Section
                SectionCard(number: 4, title: "Choose Specialization") {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(BookingSpecialization.allCases, id: \.self) { specialization in
                            SpecializationCard(
                                specialization: specialization,
                                isSelected: selectedSpecialization == specialization
                            ) {
                                handleSpecializationSelection(specialization)
                            }
                        }
                    }
                }
                
                // Next Button
                CustomButton(
                    title: "Next",
                    action: onNext,
                    isDisabled: selectedLocation == nil || selectedSpecialization == nil
                )
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .fullScreenCover(isPresented: $showLocationSearch) {
            LocationSearchView(
                selectedLocation: $selectedLocation,
                locationName: $locationName,
                isPresented: $showLocationSearch,
                onLocationSelected: { coordinate in
                    checkLocationDistance(coordinate: coordinate)
                }
            )
        }
        .sheet(isPresented: $showRankInfo) {
            RankInfoView()
        }
        .alert("Coming Soon", isPresented: $showIndustryWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Launching in 2026! We are currently only supporting Automotive and Real Estate.")
        }
        .alert("Location Out of Range", isPresented: $showLocationWarning) {
            Button("OK", role: .cancel) {
                // Clear the location selection
                selectedLocation = nil
                locationName = ""
            }
        } message: {
            Text("As a first to market app, we currently do not service your area. Please continue to check the app as we are growing and rolling out in many more locations in 2026")
        }
    }
    
    private func handleSpecializationSelection(_ specialization: BookingSpecialization) {
        // Check if this is a supported industry
        if supportedIndustries.contains(specialization) {
            // Toggle selection: if already selected, deselect it
            if selectedSpecialization == specialization {
                selectedSpecialization = nil
            } else {
                selectedSpecialization = specialization
            }
        } else {
            // Show warning for unsupported industries
            showIndustryWarning = true
            // Don't select unsupported industries
        }
    }
    
    private func checkLocationDistance(coordinate: CLLocationCoordinate2D) {
        let distance = coordinate.distance(to: ithacaNY)
        if distance > serviceRadiusMiles {
            showLocationWarning = true
        }
    }
}

// MARK: - CLLocationCoordinate2D Extension for Distance Calculation

extension CLLocationCoordinate2D {
    /// Calculate distance in miles between two coordinates using Haversine formula
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceInMeters = location1.distance(from: location2)
        let distanceInMiles = distanceInMeters / 1609.34 // Convert meters to miles
        return distanceInMiles
    }
}

// MARK: - Rank Info View

struct RankInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Pilot Ranking System")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text("Pilots are ranked based on their total flight hours, trainings, and other metrics. Higher ranks indicate more experience.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        // Display ranks in descending order: Captain -> Ensign
                        RankInfoRow(rank: 4, name: "Captain", hours: "500+ hours", description: "Elite pilots with exceptional experience. Ideal for the most challenging and high-profile assignments.")
                        RankInfoRow(rank: 3, name: "Commander", hours: "200 - 499 hours", description: "Highly experienced pilots with extensive expertise. Suitable for critical and demanding projects.")
                        RankInfoRow(rank: 2, name: "Lieutenant", hours: "75 - 199 hours", description: "Experienced pilots with solid track record. Capable of handling complex missions.")
                        RankInfoRow(rank: 1, name: "Sub Lieutenant", hours: "25 - 74 hours", description: "Developed basic skills through initial flight experience. Can handle standard assignments.")
                        RankInfoRow(rank: 0, name: "Ensign", hours: "0 - 24 hours", description: "Entry-level pilots just starting their career. Suitable for basic tasks and learning opportunities.")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Rank Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Rank Info Row

struct RankInfoRow: View {
    let rank: Int
    let name: String
    let hours: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                Text(hours)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let number: Int
    let title: String
    let content: Content
    
    init(number: Int, title: String, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                // Numbered badge
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    
                    Text("\(number)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Specialization Card

struct SpecializationCard: View {
    let specialization: BookingSpecialization
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack {
                    // Background Image
                    Image(specialization.backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .cornerRadius(12)
                    
                    // Semi-transparent overlay when selected (blue tint)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.4))
                    } else {
                        // Dark overlay for better text/icon visibility when not selected
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                    }
                    
                    // Content (Icon and Text)
                    VStack(spacing: 4) {
                        Image(systemName: specialization.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        
                        Text(specialization.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .frame(height: 28)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
            }
            .aspectRatio(2.0, contentMode: .fit)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

