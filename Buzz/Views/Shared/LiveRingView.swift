//
//  LiveRingView.swift
//  Buzz
//
//  Created by Xinyu Fang on 2/22/26.
//

import SwiftUI

struct LiveRingView: View {
    var size: CGFloat = 48
    var showLabel: Bool = true

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.purple, .red, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: size, height: size)
                .scaleEffect(isAnimating ? 1.06 : 1.0)
                .opacity(isAnimating ? 0.85 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            if showLabel {
                Text("LIVE")
                    .font(.system(size: max(7, size * 0.14), weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red)
                    .cornerRadius(3)
                    .offset(y: size / 2 + 2)
            }
        }
        .onAppear { isAnimating = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live indicator")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
