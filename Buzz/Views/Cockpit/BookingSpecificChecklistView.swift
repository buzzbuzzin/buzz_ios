//
//  BookingSpecificChecklistView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/22/25.
//

import SwiftUI
import Auth
import UIKit

struct BookingSpecificChecklistView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var checklistService: ChecklistService
    
    let booking: Booking
    private let portalURL = URL(string: "https://buzz-portal.vercel.app/")!
    
    init(booking: Booking) {
        self.booking = booking
        _checklistService = StateObject(wrappedValue: ChecklistService(bookingId: booking.id))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Booking Info Card
                BookingInfoCard(booking: booking)
                    .padding(.horizontal)
                
                // Pre-Flight Checklist
                SectionHeader(title: "Pre-Flight Checklist")
                
                if checklistService.isLoading {
                    ProgressView("Checking your status…")
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        ChecklistItemRow(
                            isComplete: checklistService.hasDroneRegistration,
                            title: "Pilot has uploaded at least one drone registration",
                            subtitle: "Add registrations in License > Drone Registration"
                        )
                        ChecklistItemRow(
                            isComplete: checklistService.hasDronePilotLicense,
                            title: "Pilot has uploaded a drone pilot license",
                            subtitle: "Upload at least one document in License > Drone Pilot License"
                        )
                        ChecklistItemRow(
                            isComplete: checklistService.isEmailVerified,
                            title: "Pilot has a verified email address",
                            subtitle: "Verify email in Profile > Personal Info"
                        )
                        
                        // Manual checklist items
                        Button(action: {
                            Task {
                                await checklistService.toggleInsurance()
                            }
                        }) {
                            ChecklistItemRow(
                                isComplete: checklistService.hasInsurance,
                                title: "Insurance",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            Task {
                                await checklistService.toggleFlightPlan()
                            }
                        }) {
                            ChecklistItemRow(
                                isComplete: checklistService.hasFlightPlan,
                                title: "Flight Plan",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            Task {
                                await checklistService.toggleFAAWaiver()
                            }
                        }) {
                            ChecklistItemRow(
                                isComplete: checklistService.hasFAAWaiver,
                                title: "FAA Waiver",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                
                if let error = checklistService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Post-Flight Checklist
                SectionHeader(title: "Post-Flight Checklist")
                
                VStack(spacing: 12) {
                    Button(action: openPortal) {
                        ChecklistItemRow(
                            isComplete: false,
                            title: "Upload recorded videos to the Pilot Portal",
                            subtitle: nil,
                            isLink: true,
                            instructions: [
                                "1. Log in to the pilot portal with your pilot account.",
                                "2. Choose this booking specifically.",
                                "3. Upload your raw video on the portal.",
                                "4. The checklist will be automatically updated if you have successfully uploaded the video."
                            ],
                            linkURL: portalURL.absoluteString
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Flight Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStatus()
        }
    }
    
    private func loadStatus() async {
        guard let pilotId = authService.currentUser?.id else {
            checklistService.errorMessage = "Pilot not found. Please sign in again."
            return
        }
        await checklistService.loadChecklistStatus(pilotId: pilotId, currentUser: authService.currentUser)
    }
    
    private func openPortal() {
        UIApplication.shared.open(portalURL, options: [:], completionHandler: nil)
    }
}

// MARK: - Subviews

private struct BookingInfoCard: View {
    let booking: Booking
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let specialization = booking.specialization {
                    Image(systemName: specialization.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.blue.gradient)
                        )
                } else {
                    Image(systemName: "airplane")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.gray.gradient)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.specialization?.displayName ?? "Flight")
                        .font(.headline)
                    Text(booking.locationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let scheduledDate = booking.scheduledDate {
                Divider()
                
                HStack {
                    Label(scheduledDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.title2)
            .fontWeight(.bold)
            .padding(.horizontal)
    }
}

private struct ChecklistItemRow: View {
    let isComplete: Bool
    let title: String
    let subtitle: String?
    var isLink: Bool = false
    var instructions: [String]?
    var linkURL: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .secondary)
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Instructions (if provided)
                if let instructions = instructions {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { _, instruction in
                            Text(instruction)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Link URL (if provided)
                if let linkURL = linkURL {
                    Text(linkURL)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                
                // Subtitle (if provided and no instructions)
                if let subtitle = subtitle, instructions == nil {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isLink ? .blue : .secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isLink {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

