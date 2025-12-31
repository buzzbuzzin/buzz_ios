//
//  BeaconView.swift
//  Buzz
//
//  Created by Xinyu Fang on 12/31/24.
//

import SwiftUI
import Auth

struct BeaconView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoading: Bool = true
    @State private var activeMissions: [BeaconMission] = []
    @State private var showOnboarding: Bool = false
    @State private var isBeaconVolunteer: Bool = false
    @State private var trainingProgress: [BeaconTrainingProgress] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 12) {
                    // Beacon Badge/Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.8), .orange.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .yellow.opacity(0.5), radius: 20)
                        
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    .padding(.top)
                    
                    Text("Beacon")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Community Emergency Response")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Program Description
                VStack(alignment: .leading, spacing: 16) {
                    Text("About Beacon Program")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 12) {
                        FeatureCard(
                            icon: "building.2.fill",
                            title: "Public Service Missions",
                            description: "Work with local police and fire departments on rescue and research flights",
                            color: .blue
                        )
                        
                        FeatureCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Emergency Assistance",
                            description: "Get help from nearby pilots when facing hazardous situations during flight",
                            color: .red
                        )
                        
                        FeatureCard(
                            icon: "dollarsign.circle.fill",
                            title: "Flexible Compensation",
                            description: "Missions can be voluntary or paid, depending on individual assignments",
                            color: .green
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // How It Works Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("How Beacon Works")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        BeaconHowItWorksStep(
                            number: 1,
                            title: "Register Your Availability",
                            description: "Set your availability and the types of missions you're interested in"
                        )
                        
                        BeaconHowItWorksStep(
                            number: 2,
                            title: "Receive Mission Alerts",
                            description: "Get notified when emergency services or nearby pilots need assistance"
                        )
                        
                        BeaconHowItWorksStep(
                            number: 3,
                            title: "Respond & Assist",
                            description: "Accept missions and help your community with critical drone operations"
                        )
                        
                        BeaconHowItWorksStep(
                            number: 4,
                            title: "Track Your Impact",
                            description: "View your contribution history and earn recognition for your service"
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Mission Types Preview
                VStack(alignment: .leading, spacing: 16) {
                    Text("Mission Types")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        MissionTypeCard(
                            icon: "flame.fill",
                            title: "Fire Department Support",
                            examples: ["Thermal imaging", "Damage assessment", "Search operations"],
                            color: .red
                        )
                        
                        MissionTypeCard(
                            icon: "shield.fill",
                            title: "Police Assistance",
                            examples: ["Search & rescue", "Traffic monitoring", "Event surveillance"],
                            color: .blue
                        )
                        
                        MissionTypeCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Research Flights",
                            examples: ["Environmental monitoring", "Wildlife tracking", "Infrastructure inspection"],
                            color: .green
                        )
                        
                        MissionTypeCard(
                            icon: "person.fill.questionmark",
                            title: "Pilot Emergency Help",
                            examples: ["Equipment failure support", "Navigation assistance", "Safety guidance"],
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Sign Up Prompt (only show if not already a volunteer)
                if !isBeaconVolunteer {
                    VStack(spacing: 16) {
                        Text("Join the Emergency Response Program")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Be part of an elite group of pilots making a difference in your community")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showOnboarding = true
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Start Onboarding")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                } else {
                    // Volunteer Status Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Beacon Volunteer")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("You're ready to respond to emergencies")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Volunteer dashboard link could go here
                        NavigationLink(destination: BeaconVolunteerDashboardView().environmentObject(authService)) {
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                Text("View Dashboard")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Beacon")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showOnboarding) {
            NavigationView {
                BeaconOnboardingView(
                    onComplete: {
                        showOnboarding = false
                        Task {
                            await loadData()
                        }
                    }
                )
                .environmentObject(authService)
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        // Check if user is a beacon volunteer
        if let userId = authService.currentUser?.id {
            do {
                let beaconService = BeaconService()
                isBeaconVolunteer = try await beaconService.isUserBeaconVolunteer(userId: userId)
                trainingProgress = try await beaconService.getTrainingProgress(userId: userId)
            } catch {
                print("Error loading beacon status: \(error)")
            }
        }
        
        // Demo data - will be replaced with actual beacon missions
        activeMissions = []
        
        isLoading = false
    }
}

// MARK: - Beacon Mission Model

struct BeaconMission: Identifiable {
    let id: UUID
    let title: String
    let type: MissionType
    let organization: String
    let isPaid: Bool
    let urgency: UrgencyLevel
    
    enum MissionType: String {
        case fire = "Fire Department"
        case police = "Police"
        case research = "Research"
        case pilotHelp = "Pilot Emergency"
    }
    
    enum UrgencyLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - How It Works Step

struct BeaconHowItWorksStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Mission Type Card

struct MissionTypeCard: View {
    let icon: String
    let title: String
    let examples: [String]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 6, height: 6)
                        
                        Text(example)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Beacon Volunteer Dashboard View

struct BeaconVolunteerDashboardView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isAvailable: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Availability Toggle
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Availability Status")
                                .font(.headline)
                            
                            Text(isAvailable ? "Ready to respond" : "Not available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isAvailable)
                            .labelsHidden()
                            .tint(.green)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Stats Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Impact")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        StatCard(title: "Missions", value: "0", icon: "flag.fill", color: .blue)
                        StatCard(title: "Hours", value: "0", icon: "clock.fill", color: .orange)
                        StatCard(title: "People Helped", value: "0", icon: "person.2.fill", color: .green)
                    }
                    .padding(.horizontal)
                }
                
                // Active Missions Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Active Missions")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Text("No active missions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Volunteer Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Emergency Flash Overlay

/// A full-screen flashing overlay that appears during urgent emergencies
/// Add this to your root view and observe NotificationManager.shared.showEmergencyFlash
struct EmergencyFlashOverlay: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @State private var isFlashing: Bool = false
    @State private var flashCount: Int = 0
    
    var body: some View {
        ZStack {
            if notificationManager.showEmergencyFlash {
                Color.red
                    .opacity(isFlashing ? 0.6 : 0.0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: isFlashing)
                    .allowsHitTesting(false)
                
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                    
                    Text("EMERGENCY")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                    
                    Text("Tap to respond")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 5)
                }
                .opacity(isFlashing ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: isFlashing)
            }
        }
        .onChange(of: notificationManager.showEmergencyFlash) { shouldFlash in
            if shouldFlash {
                startFlashing()
            } else {
                isFlashing = false
                flashCount = 0
            }
        }
        .onTapGesture {
            if notificationManager.showEmergencyFlash {
                notificationManager.stopEmergencyFlash()
                // Navigate to the emergency booking if ID is available
                if let bookingId = notificationManager.emergencyBookingId {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToEmergencyBooking"),
                        object: nil,
                        userInfo: ["bookingId": bookingId.uuidString]
                    )
                }
            }
        }
    }
    
    private func startFlashing() {
        flashCount = 0
        performFlash()
    }
    
    private func performFlash() {
        guard flashCount < 10 else { // Flash 5 times (on/off = 10 changes)
            return
        }
        
        isFlashing.toggle()
        flashCount += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if notificationManager.showEmergencyFlash {
                performFlash()
            }
        }
    }
}

