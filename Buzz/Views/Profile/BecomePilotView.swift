//
//  BecomePilotView.swift
//  Buzz
//
//  Created for Become a Pilot information view
//

import SwiftUI

struct BecomePilotView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "person.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // Title
            Text("Become a Drone Pilot")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(spacing: 16) {
                Text("Interested in becoming a drone pilot on Buzz?")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("To get started, create a new pilot account using a different email address. This will allow you to switch between your client and pilot roles.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        Text("Create a pilot account with a different email")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coming in 2026")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Direct account creation with dual roles (using the same authentication) will be available soon.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Become a Pilot")
        .navigationBarTitleDisplayMode(.inline)
    }
}

