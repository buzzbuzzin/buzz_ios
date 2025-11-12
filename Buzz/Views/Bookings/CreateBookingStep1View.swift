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
    
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Location Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Location")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Address Text Field (Uber-style)
                    Button(action: {
                        showLocationSearch = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            
                            Text(locationName.isEmpty ? "Where to?" : locationName)
                                .foregroundColor(locationName.isEmpty ? .secondary : .primary)
                                .font(.body)
                            
                            Spacer()
                            
                            if selectedLocation != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
                
                // Date Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Select Date")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    DatePicker(
                        "Booking Date",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                }
                
                // Time Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("4. Select Time")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                DatePicker(
                                    "",
                                    selection: $startTime,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("End Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                DatePicker(
                                    "",
                                    selection: $endTime,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Required Minimum Rank Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("3. Required Minimum Pilot Rank")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showRankInfo = true
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    
                    Text("Select the minimum rank required for this job")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Picker("Minimum Rank", selection: $requiredMinimumRank) {
                        ForEach(0...4, id: \.self) { rank in
                            Text(PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: rank).tierName)
                                .tag(rank)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                }
                
                // Specialization Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("5. Choose Specialization")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Select the type of drone service needed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(BookingSpecialization.allCases, id: \.self) { specialization in
                            SpecializationCard(
                                specialization: specialization,
                                isSelected: selectedSpecialization == specialization
                            ) {
                                // Toggle selection: if already selected, deselect it
                                if selectedSpecialization == specialization {
                                    selectedSpecialization = nil
                                } else {
                                    selectedSpecialization = specialization
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
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
            .padding(.vertical)
        }
        .fullScreenCover(isPresented: $showLocationSearch) {
            LocationSearchView(
                selectedLocation: $selectedLocation,
                locationName: $locationName,
                isPresented: $showLocationSearch
            )
        }
        .sheet(isPresented: $showRankInfo) {
            RankInfoView()
        }
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
                    
                    Text("Pilots are ranked based on their total flight hours. Higher ranks indicate more experience.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        RankInfoRow(rank: 0, name: "Ensign", hours: "0 - 24 hours", description: "Entry-level pilots just starting their career. Suitable for basic tasks and learning opportunities.")
                        RankInfoRow(rank: 1, name: "Sub Lieutenant", hours: "25 - 74 hours", description: "Developed basic skills through initial flight experience. Can handle standard assignments.")
                        RankInfoRow(rank: 2, name: "Lieutenant", hours: "75 - 199 hours", description: "Experienced pilots with solid track record. Capable of handling complex missions.")
                        RankInfoRow(rank: 3, name: "Commander", hours: "200 - 499 hours", description: "Highly experienced pilots with extensive expertise. Suitable for critical and demanding projects.")
                        RankInfoRow(rank: 4, name: "Captain", hours: "500+ hours", description: "Elite pilots with exceptional experience. Ideal for the most challenging and high-profile assignments.")
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

