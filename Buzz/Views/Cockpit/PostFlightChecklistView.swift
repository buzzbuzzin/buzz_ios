//
//  PostFlightChecklistView.swift
//  Buzz
//
//  Created by GPT on 12/29/25.
//

import SwiftUI
import UIKit

struct PostFlightChecklistView: View {
    @ObservedObject var checklistService: ChecklistService
    let booking: Booking
    
    private let portalURL = URL(string: "https://buzz-portal.vercel.app/")!
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section Title
                Text("Post-Flight Checklist")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                VStack(spacing: 12) {
                    Button(action: openPortal) {
                        ChecklistRow(
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
                
                Spacer(minLength: 20)
            }
        }
    }
    
    private func openPortal() {
        UIApplication.shared.open(portalURL, options: [:], completionHandler: nil)
    }
}

