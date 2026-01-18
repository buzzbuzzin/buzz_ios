import SwiftUI

struct GroundSchoolTestIntroView: View {
    let course: TrainingCourse
    let onStartTest: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Congratulations Section
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.yellow)
                        
                        Text("Milestone Reached! 🎉")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Congratulations! You've completed the required units and are ready to take your Ground School Test.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.top, 30)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Test Information Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Test Overview")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        TestInfoRow(icon: "list.number", label: "Total Questions", value: "70 Questions")
                        TestInfoRow(icon: "clock", label: "Estimated Time", value: "60 Minutes")
                        TestInfoRow(icon: "target", label: "Passing Score", value: "80% (56/70 correct)")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "book.closed")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text("Test Areas")
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                BulletPoint(text: "Regulations (30%)")
                                BulletPoint(text: "Airspace (15%)")
                                BulletPoint(text: "Weather (10%)")
                                BulletPoint(text: "Loading & Performance (5%)")
                                BulletPoint(text: "Operations (40%)")
                            }
                            .padding(.leading, 30)
                        }
                        
                        Divider()
                        
                        // Test Rules
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text("Test Rules")
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                BulletPoint(text: "You may skip questions and return to them later")
                                BulletPoint(text: "All 70 questions must be answered to submit")
                                BulletPoint(text: "You can review your answers before submitting")
                                BulletPoint(text: "The test can be retaken in 24 hours if you don't pass")
                            }
                            .padding(.leading, 30)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Start Test Button
                    Button(action: {
                        onStartTest()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Test")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Ground School Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct TestInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(label)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

#Preview {
    GroundSchoolTestIntroView(
        course: TrainingCourse(
            id: UUID(),
            title: "UAS Pilot Course",
            description: "Test course",
            duration: "10 hours",
            level: .beginner,
            category: .mandatory,
            instructor: "Test Instructor",
            instructorPictureUrl: nil,
            rating: 4.5,
            studentsCount: 100,
            isEnrolled: true,
            provider: .buzz,
            badgeId: nil,
            isRecurrent: false,
            recurrentDueDate: nil,
            requiresUasGroundSchool: false,
            requiresFlightReviewPassed: false,
            requiresRocAPassed: false,
            externalUrl: nil,
            coverImageUrl: nil,
            region: .global,
            active: true
        ),
        onStartTest: {}
    )
}

