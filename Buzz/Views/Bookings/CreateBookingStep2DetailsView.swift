//
//  CreateBookingStep2DetailsView.swift
//  Buzz
//
//  Created for Details step in booking flow
//

import SwiftUI
import MapKit

/// Property size options for real estate bookings
enum PropertySize: String, CaseIterable {
    case under5000 = "under5000"
    case above5000 = "above5000"
    
    var displayName: String {
        switch self {
        case .under5000: return "< 5,000 sq ft"
        case .above5000: return "≥ 5,000 sq ft"
        }
    }
}

struct CreateBookingStep2DetailsView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var selectedDate: Date
    @Binding var startTime: Date
    @Binding var endTime: Date?
    @Binding var selectedSpecialization: BookingSpecialization?
    @Binding var requiredMinimumRank: Int
    @Binding var propertySize: PropertySize
    
    // Search & Rescue specific bindings
    @Binding var sarAssignmentType: SARAssignmentType?
    @Binding var sarGovernmentAgency: GovernmentAgency?
    @Binding var estimatedHours: String
    @Binding var numberOfPilots: Int
    let customerRole: CustomerRole?
    
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
                
                // Pilot Rank Section (Not for Search & Rescue)
                if selectedSpecialization != .searchRescue {
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
                }
                
                // Search & Rescue Assignment Details Section
                if selectedSpecialization == .searchRescue {
                    SectionCard2(number: 3, title: "Assignment Details") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Assignment Type
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Assignment Type")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Menu {
                                    ForEach(SARAssignmentType.allCases, id: \.self) { type in
                                        Button(action: {
                                            sarAssignmentType = type
                                        }) {
                                            Label(type.displayName, systemImage: type.icon)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let assignmentType = sarAssignmentType {
                                            Image(systemName: assignmentType.icon)
                                                .foregroundColor(.blue)
                                            Text(assignmentType.displayName)
                                                .foregroundColor(.primary)
                                        } else {
                                            Image(systemName: "list.bullet")
                                                .foregroundColor(.gray)
                                            Text("Select Assignment Type")
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Agency Selection (only for government clients)
                            if customerRole == .government {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Agency")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    Menu {
                                        ForEach(GovernmentAgency.allCases, id: \.self) { agency in
                                            Button(action: {
                                                sarGovernmentAgency = agency
                                            }) {
                                                Label(agency.displayName, systemImage: agency.icon)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            if let agency = sarGovernmentAgency {
                                                Image(systemName: agency.icon)
                                                    .foregroundColor(.purple)
                                                Text(agency.displayName)
                                                    .foregroundColor(.primary)
                                            } else {
                                                Image(systemName: "building.columns")
                                                    .foregroundColor(.gray)
                                                Text("Select Agency")
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            
                            // Estimated Hours Selector
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Estimated Hours")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    ForEach([1.0, 2.0, 3.0, 4.0, 5.0], id: \.self) { hours in
                                        Button(action: {
                                            estimatedHours = String(format: "%.0f", hours)
                                        }) {
                                            VStack(spacing: 4) {
                                                Text("\(Int(hours))")
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                Text(hours == 1 ? "hour" : "hours")
                                                    .font(.caption2)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 60)
                                            .background((estimatedHours == String(format: "%.0f", hours)) ? Color.blue : Color(.systemGray5))
                                            .foregroundColor((estimatedHours == String(format: "%.0f", hours)) ? .white : .primary)
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("This is an estimate. Actual hours will be logged after the mission completes.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Number of Pilots Selector
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Number of Pilots")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    ForEach(1...5, id: \.self) { count in
                                        Button(action: {
                                            numberOfPilots = count
                                        }) {
                                            VStack(spacing: 4) {
                                                Text("\(count)")
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                Text(count == 1 ? "pilot" : "pilots")
                                                    .font(.caption2)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 60)
                                            .background(numberOfPilots == count ? Color.blue : Color(.systemGray5))
                                            .foregroundColor(numberOfPilots == count ? .white : .primary)
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Select how many pilots you need for this mission.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Property Size Section (Real Estate only)
                if selectedSpecialization == .realEstate {
                    SectionCard2(number: 4, title: "Property Size") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("🏠")
                                    .font(.system(size: 20))
                                
                                Picker("Property Size", selection: $propertySize) {
                                    ForEach(PropertySize.allCases, id: \.self) { size in
                                        Text(size.displayName)
                                            .tag(size)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            Text("Pricing varies by property size")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
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
                        isDisabled: {
                            // Basic validation
                            if selectedLocation == nil || locationName.isEmpty {
                                return true
                            }
                            
                            // S&R specific validation
                            if selectedSpecialization == .searchRescue {
                                // Assignment type is required
                                if sarAssignmentType == nil {
                                    return true
                                }
                                
                                // Agency is required for government clients
                                if customerRole == .government && sarGovernmentAgency == nil {
                                    return true
                                }
                            }
                            
                            return false
                        }()
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
