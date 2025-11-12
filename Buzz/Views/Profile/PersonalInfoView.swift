//
//  PersonalInfoView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct PersonalInfoView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        List {
            // Name Card
            NavigationLink(destination: NameEditView()) {
                PersonalInfoCard(
                    title: "Name",
                    value: authService.userProfile?.fullName ?? "Not set",
                    icon: "person.fill"
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Email Card
            NavigationLink(destination: EmailEditView()) {
                PersonalInfoCard(
                    title: "Email",
                    value: authService.userProfile?.email ?? "Not set",
                    icon: "envelope.fill"
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Phone Card
            NavigationLink(destination: PhoneEditView()) {
                PersonalInfoCard(
                    title: "Phone",
                    value: authService.userProfile?.phone ?? "Not set",
                    icon: "phone.fill"
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Call Sign Card (Pilot only)
            if authService.userProfile?.userType == .pilot {
                NavigationLink(destination: CallSignEditView()) {
                    PersonalInfoCard(
                        title: "Call Sign",
                        value: authService.userProfile?.callSign ?? "Not set",
                        icon: "airplane.circle.fill"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Gender Card (Hidden)
//            NavigationLink(destination: GenderEditView()) {
//                PersonalInfoCard(
//                    title: "Gender",
//                    value: authService.userProfile?.gender?.displayName ?? "Not set",
//                    icon: "person.2.fill"
//                )
//            }
//            .buttonStyle(PlainButtonStyle())
            
            // Identity Verification Card
            NavigationLink(destination: GovernmentIDView()) {
                PersonalInfoCard(
                    title: "Identity Verification",
                    value: "Verify your identity",
                    icon: "person.badge.shield.checkmark.fill"
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .navigationTitle("Personal info")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PersonalInfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

