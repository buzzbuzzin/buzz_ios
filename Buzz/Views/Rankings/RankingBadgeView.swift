//
//  RankingBadgeView.swift
//  Buzz
//
//  Created by Xinyu Fang on 10/31/25.
//

import SwiftUI

struct RankingBadgeView: View {
    let stats: PilotStats
    var size: BadgeSize = .medium
    
    enum BadgeSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 30
            case .medium: return 50
            case .large: return 80
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .headline
            case .large: return .title2
            }
        }
    }
    
    var body: some View {
        VStack(spacing: size == .small ? 4 : 8) {
            ZStack {
                Circle()
                    .fill(tierColor)
                    .frame(width: size.iconSize, height: size.iconSize)
                    .shadow(color: tierColor.opacity(0.5), radius: 8)
                
                Image(systemName: "star.fill")
                    .font(.system(size: size.iconSize * 0.5))
                    .foregroundColor(.white)
                
                Text("\(stats.tier)")
                    .font(.system(size: size.iconSize * 0.3, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(stats.tierName)
                .font(size.fontSize)
                .fontWeight(.semibold)
            
            if size != .small {
                Text(String(format: "%.1f hrs", stats.totalFlightHours))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var tierColor: Color {
        switch stats.tier {
        case 0: return .gray
        case 1: return .brown
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .mint
        case 6: return .cyan
        case 7: return .blue
        case 8: return .indigo
        case 9: return .purple
        case 10: return .pink
        default: return .gray
        }
    }
}

