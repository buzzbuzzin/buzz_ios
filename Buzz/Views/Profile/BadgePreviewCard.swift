//
//  BadgePreviewCard.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

struct BadgePreviewCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.provider.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: badge.provider.icon)
                    .font(.system(size: 24))
                    .foregroundColor(badge.provider.color)
                
                // Expiration indicator overlay
                if badge.isExpiringSoon {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        )
                        .offset(x: 18, y: -18)
                }
            }
            
            Text(badge.courseTitle)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
            
            // Always reserve space for expiration text to keep badges aligned
            if badge.isExpiringSoon, let daysLeft = badge.daysUntilExpiration {
                Text("\(daysLeft)d left")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                    .padding(.top, 2)
            } else {
                // Invisible placeholder to maintain consistent height
                Text(" ")
                    .font(.caption2)
                    .opacity(0)
                    .padding(.top, 2)
            }
        }
    }
}

