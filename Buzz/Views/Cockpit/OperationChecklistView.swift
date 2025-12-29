//
//  OperationChecklistView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/29/25.
//

import SwiftUI

struct OperationChecklistView: View {
    @ObservedObject var checklistService: ChecklistService
    let booking: Booking
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section Title
                Text("Operation Checklist")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                if checklistService.isLoading {
                    ProgressView("Checking your status…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 12) {
                        // Automatic checklist items
                        ChecklistRow(
                            isComplete: checklistService.hasDroneRegistration,
                            title: "Pilot has uploaded at least one drone registration",
                            subtitle: "Add registrations in License > Drone Registration"
                        )
                        
                        ChecklistRow(
                            isComplete: checklistService.hasDronePilotLicense,
                            title: "Pilot has uploaded a drone pilot license",
                            subtitle: "Upload at least one document in License > Drone Pilot License"
                        )
                        
                        ChecklistRow(
                            isComplete: checklistService.isEmailVerified,
                            title: "Pilot has a verified email address",
                            subtitle: "Verify email in Profile > Personal Info"
                        )
                        
                        // Manual checklist item - Insurance
                        Button(action: {
                            Task {
                                await checklistService.toggleInsurance()
                            }
                        }) {
                            ChecklistRow(
                                isComplete: checklistService.hasInsurance,
                                title: "Insurance",
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
                
                Spacer(minLength: 20)
            }
        }
    }
}

