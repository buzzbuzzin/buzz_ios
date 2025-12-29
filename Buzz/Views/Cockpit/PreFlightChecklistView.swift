//
//  PreFlightChecklistView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/29/25.
//

import SwiftUI

struct PreFlightChecklistView: View {
    @ObservedObject var checklistService: ChecklistService
    let booking: Booking
    
    // Section expansion states
    @State private var isAviationRestrictionsExpanded = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section Title
                Text("Pre-Flight Checklist")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Aviation Restrictions and Hazards Section
                CollapsibleSection(
                    title: "AVIATION RESTRICTIONS AND HAZARDS",
                    isExpanded: $isAviationRestrictionsExpanded
                ) {
                    VStack(spacing: 12) {
                        PreFlightChecklistItem(
                            text: "If flight will be nearer than 5.6 km (3 NM) away from airports, or 1.9 km (1 NM) away from helicopters, call airport operator in advance to understand established UAS procedures at that aerodrome and to secure permission. Check apps for safe flying zones. Check LAANC and IACRA web pages. Check FAA Flight Supplements and Water Aerodrome Supplements."
                        )
                        
                        PreFlightChecklistItem(
                            text: "If flight will be in Controlled Airspace or Restricted Airspace, confirm that drone is accepted for Controlled Airspace operation. Secure permission from airspace authority and understand procedures. Check apps for safe flying zones. Check LAANC and IACRA web pages. Check Designated Airspace Handbook."
                        )
                        
                        PreFlightChecklistItem(
                            text: "If flight will be nearer than 5.6 km (3 NM) from a military aerodrome, ensure an SFOC has been approved. Secure permission from airspace authority and understand procedures. Check apps for safe flying zones. Check LAANC and IACRA web pages. Check Designated Airspace Handbook."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Locate other aerodromes in flight area and ensure flight stays out of established flight patterns of those aerodromes. Check app for safe flying zones. Check LAANC and IACRA web pages. Check FAA Flight Supplements and Water Aerodrome Supplements."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Ensure no impacting temporary aviation restrictions are in effect. Check LAANC and the FAA NOTAM site."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check visually and audibly for nearby low altitude air operations such as helicopters, seaplanes, hot air balloons, and ultra-light aircraft."
                        )
                        
                        PreFlightChecklistItem(
                            text: "Check suitability of current weather and weather forecast for the duration of the operation (wind, rain, snow, fog, temperature)."
                        )
                    }
                }
                .padding(.horizontal)
                
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

// MARK: - Collapsible Section

struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header (Tappable)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(isExpanded ? 12 : 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content (Collapsible)
            if isExpanded {
                VStack(spacing: 12) {
                    content()
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - Pre-Flight Checklist Item

struct PreFlightChecklistItem: View {
    let text: String
    @State private var isChecked: Bool = false
    
    var body: some View {
        Button(action: {
            isChecked.toggle()
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .secondary)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.top, 2)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Checklist Row

struct ChecklistRow: View {
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
