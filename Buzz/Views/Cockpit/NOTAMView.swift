//
//  NOTAMView.swift
//  Buzz
//
//  Created for Cockpit feature implementation
//

import SwiftUI

struct NOTAMView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .padding(.top, 100)
            
            Text("NOTAMs")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Notice to Airmen")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("This feature is currently under development")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .navigationTitle("NOTAMs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        NOTAMView()
    }
}
