//
//  PremiumIntroAnimationView.swift
//  Buzz
//
//  Created by Codex on 3/7/24.
//

import SwiftUI
import Combine

struct PremiumIntroAnimationView: View {
    let onFinished: () -> Void
    private let animationDuration: TimeInterval = 3.6
    private let flashInterval: TimeInterval = 0.35
    private let specializations = BookingSpecialization.allCases
    private let collageCardAspectRatio: CGFloat = 1.55
    private let collageColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    @State private var titleOpacity: Double = 0
    @State private var collageOpacity: Double = 0
    @State private var highlightedIndices: Set<Int> = []
    @State private var timerCancellable: AnyCancellable?
    @State private var hasCompleted = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Buzz Presents")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(titleOpacity)

                    Text("Premium missions across every industry")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(titleOpacity)
                }

                LazyVGrid(columns: collageColumns, spacing: 12) {
                    ForEach(Array(specializations.enumerated()), id: \.offset) { index, specialization in
                        PremiumSpecializationCard(
                            specialization: specialization,
                            aspectRatio: collageCardAspectRatio,
                            isHighlighted: highlightedIndices.contains(index)
                        )
                        .opacity(collageOpacity)
                        .scaleEffect(highlightedIndices.contains(index) ? 1.03 : 1.0)
                        .animation(.easeInOut(duration: flashInterval * 0.7), value: highlightedIndices)
                    }
                }
                .padding(.horizontal, 24)

                Text("Unlock premium bookings tailored to your specialization.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Button(action: finishAnimation) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 40)
            }
            .padding(.top, 40)

            Button(action: finishAnimation) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(20)
            }
        }
        .onAppear(perform: startAnimation)
        .onDisappear {
            timerCancellable?.cancel()
        }
    }

    private func startAnimation() {
        withAnimation(.easeIn(duration: 0.7)) {
            titleOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.6)) {
                collageOpacity = 1.0
            }
            startFlashing()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            finishAnimation()
        }
    }

    private func startFlashing() {
        timerCancellable?.cancel()
        let timer = Timer.publish(every: flashInterval, on: .main, in: .common)
        timerCancellable = timer.autoconnect().sink { _ in
            var newHighlights: Set<Int> = []
            while newHighlights.count < 4 && newHighlights.count < specializations.count {
                newHighlights.insert(Int.random(in: 0..<specializations.count))
            }

            withAnimation(.easeInOut(duration: flashInterval * 0.7)) {
                highlightedIndices = newHighlights
            }
        }
    }

    private func finishAnimation() {
        guard !hasCompleted else { return }
        hasCompleted = true
        timerCancellable?.cancel()
        withAnimation(.easeInOut(duration: 0.4)) {
            titleOpacity = 0
            collageOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onFinished()
        }
    }
}

private struct PremiumSpecializationCard: View {
    let specialization: BookingSpecialization
    let aspectRatio: CGFloat
    let isHighlighted: Bool
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Image(specialization.backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                
                VStack(spacing: 4) {
                    Image(systemName: specialization.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(specialization.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isHighlighted ? 0.25 : 0))
            )
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}
