//
//  ChecklistTabView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/29/25.
//

import SwiftUI
import Auth

enum ChecklistTab: String, CaseIterable {
    case operation = "Operation"
    case siteSurvey = "Site Survey"
    case preFlight = "Pre-Flight"
    case postFlight = "Post-Flight"

    var icon: String {
        switch self {
        case .operation:
            return "gearshape.fill"
        case .siteSurvey:
            return "doc.text.magnifyingglass"
        case .preFlight:
            return "airplane.departure"
        case .postFlight:
            return "airplane.arrival"
        }
    }
}

struct ChecklistTabView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var checklistService: ChecklistService
    @State private var selectedTab: ChecklistTab = .operation
    @State private var hasLoadedInitialData = false
    
    let booking: Booking
    
    init(booking: Booking) {
        self.booking = booking
        _checklistService = StateObject(wrappedValue: ChecklistService(bookingId: booking.id))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Booking Info Header
            BookingInfoHeader(booking: booking)
                .padding()
                .background(Color(.systemBackground))
            
            // Tab Selection
            HStack(spacing: 0) {
                ForEach(ChecklistTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Tab Content
            Group {
                switch selectedTab {
                case .operation:
                    OperationChecklistView(
                        checklistService: checklistService,
                        booking: booking
                    )
                case .siteSurvey:
                    SiteSurveyChecklistView(booking: booking)
                case .preFlight:
                    PreFlightChecklistView(
                        checklistService: checklistService,
                        booking: booking
                    )
                case .postFlight:
                    PostFlightChecklistView(
                        checklistService: checklistService,
                        booking: booking
                    )
                }
            }
        }
        .navigationTitle("Flight Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authService.activeUserId) {
            guard !hasLoadedInitialData else { return }
            hasLoadedInitialData = await loadStatus()
        }
    }
    
    private func loadStatus() async -> Bool {
        guard let pilotId = authService.activeUserId else {
            checklistService.errorMessage = "Pilot not found. Please sign in again."
            return false
        }
        await checklistService.loadChecklistStatus(pilotId: pilotId, currentUser: authService.currentUser)
        return true
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let tab: ChecklistTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 16, weight: .medium))
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(isSelected ? .blue : .secondary)
                .padding(.vertical, 12)
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 3)
                    .cornerRadius(1.5)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Booking Info Header

private struct BookingInfoHeader: View {
    let booking: Booking
    
    var body: some View {
        HStack(spacing: 12) {
            // Specialization Icon
            if let specialization = booking.specialization {
                Image(systemName: specialization.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.blue.gradient)
                    )
            } else {
                Image(systemName: "airplane")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.gray.gradient)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.specialization?.displayName ?? "Flight")
                    .font(.headline)
                Text(booking.locationName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let scheduledDate = booking.scheduledDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(scheduledDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(scheduledDate, style: .time)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}
