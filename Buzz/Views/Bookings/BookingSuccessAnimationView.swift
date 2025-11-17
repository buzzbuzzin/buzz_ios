//
//  BookingSuccessAnimationView.swift
//  Buzz
//
//  Luxury animated booking success flow
//

import SwiftUI

struct BookingSuccessAnimationView: View {
    let createdBooking: Booking
    @Environment(\.dismiss) private var dismiss
    @Binding var shouldShowBookingDetail: Bool
    
    @State private var showCheckmark = false
    @State private var showSuccessText = false
    @State private var showFindingPilots = false
    @State private var showPilotMatched = false
    @State private var pulseAnimation = false
    @State private var rotationAnimation = 0.0
    @State private var searchPulse = false
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.3),
                    Color(red: 0.2, green: 0.2, blue: 0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated particles in background
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: CGFloat.random(in: 20...60))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...2)),
                        value: pulseAnimation
                    )
                    .opacity(pulseAnimation ? 0.1 : 0.02)
            }
            
            VStack(spacing: 30) {
                Spacer()
                
                if !showFindingPilots {
                    // Success checkmark animation
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green.opacity(0.3), Color.green]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                            .opacity(showCheckmark ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showCheckmark)
                        
                        // Checkmark
                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green, Color.mint]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(showCheckmark ? 1 : 0)
                            .rotationEffect(.degrees(showCheckmark ? 0 : -180))
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showCheckmark)
                    }
                    .shadow(color: Color.green.opacity(0.5), radius: 20, x: 0, y: 0)
                    
                    // Success text
                    VStack(spacing: 12) {
                        Text("Booking Created")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white, Color(white: 0.9)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(showSuccessText ? 1 : 0)
                            .offset(y: showSuccessText ? 0 : 20)
                            .animation(.easeOut(duration: 0.5).delay(0.4), value: showSuccessText)
                        
                        Text("Payment successful")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .opacity(showSuccessText ? 1 : 0)
                            .offset(y: showSuccessText ? 0 : 20)
                            .animation(.easeOut(duration: 0.5).delay(0.5), value: showSuccessText)
                    }
                    
                } else if !showPilotMatched {
                    // Finding pilots animation
                    ZStack {
                        // Rotating search rings
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.3),
                                            Color.blue.opacity(0.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 100 + CGFloat(index * 30), height: 100 + CGFloat(index * 30))
                                .scaleEffect(searchPulse ? 1.3 : 1.0)
                                .opacity(searchPulse ? 0 : 0.6)
                                .animation(
                                    Animation.easeOut(duration: 2)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(index) * 0.3),
                                    value: searchPulse
                                )
                        }
                        
                        // Center icon
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(rotationAnimation))
                    }
                    .shadow(color: Color.blue.opacity(0.5), radius: 20, x: 0, y: 0)
                    
                    // Finding pilots text
                    VStack(spacing: 12) {
                        Text("Finding Pilots")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white, Color(white: 0.9)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("in your region...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                } else {
                    // Pilot matched animation
                    ZStack {
                        // Success burst
                        ForEach(0..<8) { index in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.yellow.opacity(0.6),
                                            Color.yellow.opacity(0.0)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 100, height: 4)
                                .offset(x: 50)
                                .rotationEffect(.degrees(Double(index) * 45))
                                .scaleEffect(showPilotMatched ? 1.5 : 0)
                                .opacity(showPilotMatched ? 0 : 1)
                                .animation(.easeOut(duration: 0.8), value: showPilotMatched)
                        }
                        
                        // Celebration emoji
                        Text("🎉")
                            .font(.system(size: 80))
                            .scaleEffect(showPilotMatched ? 1 : 0.5)
                            .rotationEffect(.degrees(showPilotMatched ? 0 : -180))
                            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showPilotMatched)
                    }
                    .shadow(color: Color.yellow.opacity(0.7), radius: 30, x: 0, y: 0)
                    
                    // Pilot matched text
                    VStack(spacing: 12) {
                        Text("Pilot Matched!")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white, Color(white: 0.9)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(showPilotMatched ? 1 : 0.8)
                            .opacity(showPilotMatched ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showPilotMatched)
                        
                        Text("Available pilots will be notified")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .opacity(showPilotMatched ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.4), value: showPilotMatched)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Step 1: Show success checkmark (0-1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCheckmark = true
            showSuccessText = true
            pulseAnimation = true
        }
        
        // Step 2: Transition to finding pilots (1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showFindingPilots = true
            }
            searchPulse = true
            // Start rotation animation
            withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotationAnimation = 360
            }
        }
        
        // Step 3: Show pilot matched (after 5s total, so 5s - 1.5s = 3.5s more)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPilotMatched = true
            }
        }
        
        // Step 4: Navigate to bookings (after 6.5s total)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            shouldShowBookingDetail = true
            dismiss()
        }
    }
}

// Preview with mock booking
#Preview {
    BookingSuccessAnimationView(
        createdBooking: Booking(
            id: UUID(),
            customerId: UUID(),
            pilotId: nil,
            locationLat: 37.7749,
            locationLng: -122.4194,
            locationName: "San Francisco",
            scheduledDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            specialization: .motionPicture,
            description: "Test booking",
            paymentAmount: 500,
            tipAmount: nil,
            status: .available,
            createdAt: Date(),
            estimatedFlightHours: 2.0,
            pilotRated: nil,
            customerRated: nil,
            requiredMinimumRank: 0
        ),
        shouldShowBookingDetail: .constant(false)
    )
}

