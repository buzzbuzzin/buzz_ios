//
//  ChecklistView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/11/25.
//

import SwiftUI
import Auth
import UIKit

struct ChecklistView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var checklistService = ChecklistService()
    
    private let portalURL = URL(string: "https://buzz-portal.vercel.app/")!
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
                            checklistService.hasInsurance.toggle()
                        }) {
                            ChecklistItemRow(
                                isComplete: checklistService.hasInsurance,
                                title: "Insurance",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityHint("Tap to toggle")

                        Button(action: {
                            checklistService.hasFlightPlan.toggle()
                        }) {
                            ChecklistItemRow(
                                isComplete: checklistService.hasFlightPlan,
                                title: "Flight Plan",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityHint("Tap to toggle")

                        Button(action: {
                            checklistService.hasFAAWaiver.toggle()
                        }) {
                            ChecklistItemRow(
                                isComplete: checklistService.hasFAAWaiver,
                                title: "FAA Waiver",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityHint("Tap to toggle")
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
                            subtitle: portalURL.absoluteString,
                            isLink: true
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
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .secondary)
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let subtitle = subtitle {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isComplete ? "complete" : "incomplete")")
        .accessibilityValue(isComplete ? "Done" : "Not done")
    }
}
