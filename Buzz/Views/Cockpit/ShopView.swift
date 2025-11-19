//
//  ShopView.swift
//  Buzz
//
//  Created for Shop feature
//

import SwiftUI

struct ShopView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bag.fill")
                .font(.system(size: 80))
                .foregroundColor(.pink.opacity(0.6))
            
            Text("Coming Soon!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("The shop will be available soon. Stay tuned!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
    }
}

