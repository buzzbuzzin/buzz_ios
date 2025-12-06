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
            VStack(spacing: 16) {
                // Location Section
                SectionCard2(number: 1, title: "Location") {
                    Button(action: {
                        showLocationSearch = true
                    }) {
                        HStack {
                            Text("📍")
                                .font(.system(size: 20))
                            
                            Text(locationName.isEmpty ? "Where to?" : locationName)
                                .foregroundColor(locationName.isEmpty ? .secondary : .primary)
                                .font(.body)
                                .lineLimit(1)
                            
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
                SectionCard2(number: 2, title: "Date & Time") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Date picker
                        HStack {
                            Text("📅")
                                .font(.system(size: 20))
                            
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Time picker
                        HStack {
                            Text("🕐")
                                .font(.system(size: 20))
                            
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
                            
                            DatePicker(
                                "",
                                selection: $startTime,
                                in: timeRange,
                                displayedComponents: [.hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Warning for Automotive
                        if selectedSpecialization == .automotive {
                            HStack(spacing: 8) {
                                Text("⚠️")
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
                SectionCard2(number: 3, title: "Pilot Rank") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("⭐")
                                .font(.system(size: 20))
                            
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
                            .labelsHidden()
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
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
                        
                        Text("Pricing varies by rank")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
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
                .padding(.bottom, 20)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showLocationSearch) {
            LocationSearchView(
                selectedLocation: $selectedLocation,
                locationName: $locationName,
                isPresented: $showLocationSearch,
                onLocationSelected: nil // Optional callback, not needed here
            )
        }
        .sheet(isPresented: $showRankInfo) {
            RankInfoView()
        }
    }
}

// MARK: - Section Card for Step 2

struct SectionCard2<Content: View>: View {
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
