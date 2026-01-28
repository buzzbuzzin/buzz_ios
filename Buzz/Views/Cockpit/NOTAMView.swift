//
//  NOTAMView.swift
//  Buzz
//
//  Created for Cockpit feature implementation
//

import SwiftUI
import CoreLocation
import Auth

struct NOTAMView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var notamService = NOTAMService()
    @StateObject private var locationManager = WeatherLocationManager()
    @State private var selectedGrouping: NOTAMGrouping = .airport
    
    enum NOTAMGrouping: String, CaseIterable {
        case airport = "Airport"
        case category = "Category"
        case all = "All"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Grouping Picker
                Picker("Group by", selection: $selectedGrouping) {
                    ForEach(NOTAMGrouping.allCases, id: \.self) { grouping in
                        Text(grouping.rawValue).tag(grouping)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Content based on grouping
                if notamService.isLoading {
                    NOTAMLoadingView()
                } else if notamService.nearbyNOTAMs.isEmpty {
                    NOTAMEmptyStateView(errorMessage: notamService.errorMessage)
                } else {
                    switch selectedGrouping {
                    case .airport:
                        AirportGroupedView(notamService: notamService)
                    case .category:
                        CategoryGroupedView(notamService: notamService)
                    case .all:
                        AllNOTAMsView(notamService: notamService)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("NOTAMs")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadNOTAMData()
        }
        .refreshable {
            notamService.clearCache()
            await loadNOTAMData()
        }
        .onChange(of: locationManager.currentLocation?.latitude) { _, _ in
            if locationManager.currentLocation != nil {
                Task {
                    await loadNearbyNOTAMs()
                }
            }
        }
    }
    
    private func loadNOTAMData() async {
        // Request location permission if needed
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        }
        
        // Start location updates (if permission granted)
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
            // Wait a moment for location to be acquired
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Load nearby NOTAMs
        await loadNearbyNOTAMs()
    }
    
    private func loadNearbyNOTAMs() async {
        guard let userProfile = authService.userProfile,
              userProfile.userType == .pilot else { return }
        
        // Wait for location if not available
        var deviceLocation: CLLocationCoordinate2D? = locationManager.currentLocation
        if deviceLocation == nil {
            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                deviceLocation = locationManager.currentLocation
                if deviceLocation != nil {
                    break
                }
            }
        }
        
        guard let location = deviceLocation else {
            print("Unable to get device location for NOTAMs")
            return
        }
        
        do {
            _ = try await notamService.fetchNOTAMsNearLocation(coordinate: location)
        } catch {
            print("Error fetching nearby NOTAMs: \(error.localizedDescription)")
        }
    }
}

// MARK: - NOTAM Loading View

private struct NOTAMLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Fetching NOTAMs...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - NOTAM Empty State View

private struct NOTAMEmptyStateView: View {
    let errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.6))
            
            Text("No NOTAMs Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("No active NOTAMs were found for nearby airports.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Airport Grouped View

private struct AirportGroupedView: View {
    @ObservedObject var notamService: NOTAMService
    
    var body: some View {
        let grouped = notamService.notamsGroupedByAirport()
        let sortedAirports = grouped.keys.sorted()
        
        LazyVStack(spacing: 16) {
            ForEach(sortedAirports, id: \.self) { airport in
                AirportSection(airport: airport, notams: grouped[airport] ?? [])
            }
        }
        .padding(.horizontal)
    }
}

private struct AirportSection: View {
    let airport: String
    let notams: [NOTAM]
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Airport Header
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "airplane.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text(airport)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("(\(notams.count) NOTAM\(notams.count == 1 ? "" : "s"))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ForEach(notams) { notam in
                    NOTAMCard(notam: notam)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Category Grouped View

private struct CategoryGroupedView: View {
    @ObservedObject var notamService: NOTAMService
    
    var body: some View {
        let grouped = notamService.notamsGroupedByCategory()
        let sortedCategories = grouped.keys.sorted { $0.rawValue < $1.rawValue }
        
        LazyVStack(spacing: 16) {
            ForEach(sortedCategories, id: \.self) { category in
                CategorySection(category: category, notams: grouped[category] ?? [])
            }
        }
        .padding(.horizontal)
    }
}

private struct CategorySection: View {
    let category: NOTAMCategory
    let notams: [NOTAM]
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category Header
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(categoryColor)
                    
                    Text(category.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("(\(notams.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ForEach(notams) { notam in
                    NOTAMCard(notam: notam)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    private var categoryColor: Color {
        switch category.color {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

// MARK: - All NOTAMs View

private struct AllNOTAMsView: View {
    @ObservedObject var notamService: NOTAMService
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(notamService.nearbyNOTAMs) { notam in
                NOTAMCard(notam: notam, showAirport: true)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - NOTAM Card

private struct NOTAMCard: View {
    let notam: NOTAM
    var showAirport: Bool = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .top) {
                // Category Badge
                CategoryBadge(category: notam.category)
                
                Spacer()
                
                // Status Badge
                NOTAMStatusBadge(notam: notam)
            }
            
            // NOTAM Number and Airport
            HStack {
                Text(notam.notamNumber)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if showAirport {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(notam.icaoCode)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            
            // Excerpt (AI interpretation summary)
            Text(notam.interpretation.excerpt)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? nil : 2)
            
            // Validity Period
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(notam.shortValidity)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Expandable Details
            if isExpanded {
                Divider()
                
                // Full Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(notam.interpretation.description)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                // Affected Elements
                if !notam.interpretation.affectedElements.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Affected Elements")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ForEach(notam.interpretation.affectedElements) { element in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(element.identifier) (\(element.type))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(element.details)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Schedule Information
                if !notam.interpretation.schedules.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schedule")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ForEach(notam.interpretation.schedules) { schedule in
                            Text("• \(schedule.description)")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Validity Period Details
                VStack(alignment: .leading, spacing: 4) {
                    Text("Valid Period")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(notam.validityPeriod)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                // Raw NOTAM (collapsible)
                DisclosureGroup("Raw NOTAM") {
                    Text(notam.rawText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Expand/Collapse Button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Spacer()
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Category Badge

private struct CategoryBadge: View {
    let category: NOTAMCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            Text(category.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .foregroundColor(badgeColor)
        .cornerRadius(6)
    }
    
    private var badgeColor: Color {
        switch category.color {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .orange // Yellow is hard to read, use orange
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

// MARK: - NOTAM Status Badge

private struct NOTAMStatusBadge: View {
    let notam: NOTAM
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .foregroundColor(statusColor)
        .cornerRadius(6)
    }
    
    private var statusColor: Color {
        if notam.isActive {
            return .green
        } else if notam.isUpcoming {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if notam.isActive {
            return "ACTIVE"
        } else if notam.isUpcoming {
            return "UPCOMING"
        } else if notam.isPermanent {
            return "PERM"
        } else {
            return "INACTIVE"
        }
    }
}

#Preview {
    NavigationView {
        NOTAMView()
            .environmentObject(AuthService())
    }
}
