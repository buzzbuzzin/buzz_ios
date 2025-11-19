//
//  CreateBookingStep2DetailsView.swift
//  Buzz
//
//  Created for Details step in booking flow
//

import SwiftUI
import MapKit

struct CreateBookingStep2DetailsView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var selectedDate: Date
    @Binding var startTime: Date
    @Binding var endTime: Date?
    @Binding var selectedSpecialization: BookingSpecialization?
    @Binding var requiredMinimumRank: Int
    
    @State private var showLocationSearch = false
    @State private var showRankInfo = false
    
    let onBack: () -> Void
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
                        "",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .padding(.leading)
                }
                
                // Time Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("3. Select Time")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if selectedSpecialization == .automotive {
                        Text("For Automotive industry, start time must be no later than noon")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal)
                    }
                    
                    // Create time range for Automotive (8 AM - 12 PM) or full day for others
                    let calendar = Calendar.current
                    let timeRange: ClosedRange<Date> = {
                        if selectedSpecialization == .automotive {
                            let startOfDay = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                            let endOfDay = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                            return startOfDay...endOfDay
                        } else {
                            let startOfDay = calendar.startOfDay(for: selectedDate)
                            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: selectedDate) ?? selectedDate
                            return startOfDay...endOfDay
                        }
                    }()
                    
                    // Start Time and End Time in HStack
                    HStack(alignment: .top, spacing: 12) {
                        // Start Time on the left
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start Time")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            DatePicker(
                                "",
                                selection: $startTime,
                                in: timeRange,
                                displayedComponents: [.hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // End Time on the right
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack(spacing: 4) {
                                Text("End Time (Optional)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Toggle button to clear end time
                                if endTime != nil {
                                    Button(action: {
                                        endTime = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                            
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { endTime ?? calendar.date(byAdding: .hour, value: 2, to: startTime) ?? startTime },
                                    set: { endTime = $0 }
                                ),
                                in: startTime...,
                                displayedComponents: [.hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)
                }
                
                // Required Minimum Rank Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("4. Pilot Rank")
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
                    
                    Text("Booking price varies with different rank.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Picker("Minimum Rank", selection: $requiredMinimumRank) {
                        // For Automotive, exclude Ensign (rank 0), start from Sub Lieutenant (rank 1)
                        // Display ranks in descending order: Captain (4) -> Ensign (0)
                        let rankRange = selectedSpecialization == .automotive ? (1...4) : (0...4)
                        ForEach(Array(rankRange.reversed()), id: \.self) { rank in
                            Text(PilotStats(pilotId: UUID(), totalFlightHours: 0, completedBookings: 0, tier: rank).tierName)
                                .tag(rank)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    .onAppear {
                        // Ensure rank is valid for Automotive (must be at least 1)
                        // Default to Captain (4) if not set or invalid
                        if selectedSpecialization == .automotive && requiredMinimumRank < 1 {
                            requiredMinimumRank = 4 // Default to Captain for Automotive
                        } else if requiredMinimumRank < 0 || requiredMinimumRank > 4 {
                            requiredMinimumRank = 4 // Default to Captain
                        }
                    }
                    .onChange(of: selectedSpecialization) { _, newSpecialization in
                        // Reset rank if switching to Automotive and current rank is Ensign
                        if newSpecialization == .automotive && requiredMinimumRank < 1 {
                            requiredMinimumRank = 4 // Default to Captain for Automotive
                        }
                    }
                }
                
                // Navigation Buttons
                HStack(spacing: 12) {
                    Button("Back") {
                        onBack()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    
                    CustomButton(
                        title: "Next",
                        action: onNext,
                        isDisabled: selectedLocation == nil || locationName.isEmpty
                    )
                    .frame(maxWidth: .infinity)
                }
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

