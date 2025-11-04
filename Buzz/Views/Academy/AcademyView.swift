//
//  AcademyView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI
import Auth

struct AcademyView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedCategory: TrainingCourse.CourseCategory? = nil
    @State private var selectedProvider: TrainingCourse.CourseProvider? = nil
    @State private var courses: [TrainingCourse] = []
    @State private var recurrentNotices: [RecurrentTrainingNotice] = []
    @State private var isLoading = false
    @State private var showRecurrentNotices = true
    
    func toggleEnrollment(for courseId: UUID) {
        if let index = courses.firstIndex(where: { $0.id == courseId }) {
            courses[index].isEnrolled.toggle()
        }
    }
    
    private let allCategories: [TrainingCourse.CourseCategory] = [
        .safety, .operations, .photography, .cinematography, .inspection, .mapping
    ]
    
    private let allProviders: [TrainingCourse.CourseProvider] = [
        .buzz, .amazon, .tmobile, .other
    ]
    
    var filteredCourses: [TrainingCourse] {
        var filtered = courses
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let provider = selectedProvider {
            filtered = filtered.filter { $0.provider == provider }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Recurrent Training Notices Section
                if showRecurrentNotices && !recurrentNotices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recurrent Training Due")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                showRecurrentNotices.toggle()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recurrentNotices) { notice in
                                    RecurrentTrainingCard(notice: notice)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                    .background(Color(.systemGray6))
                }
                
                // Provider Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All Providers Button
                        ProviderChip(
                            title: "All Providers",
                            icon: "square.grid.2x2",
                            isSelected: selectedProvider == nil
                        ) {
                            selectedProvider = nil
                        }
                        
                        ForEach(allProviders, id: \.self) { provider in
                            ProviderChip(
                                title: provider.rawValue,
                                icon: provider.icon,
                                isSelected: selectedProvider == provider,
                                color: provider.color
                            ) {
                                selectedProvider = provider
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All Categories Button
                        CategoryChip(
                            title: "All",
                            icon: "square.grid.2x2",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(allCategories, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGray6))
                
                // Courses List
                if isLoading {
                    LoadingView(message: "Loading courses...")
                } else if filteredCourses.isEmpty {
                    EmptyStateView(
                        icon: "book.closed",
                        title: "No Courses Available",
                        message: "Check back soon for new training courses"
                    )
                } else {
                    List {
                        ForEach(filteredCourses) { course in
                            NavigationLink(destination: CourseDetailView(
                                course: courses.first(where: { $0.id == course.id }) ?? course,
                                onEnrollmentChange: { 
                                    toggleEnrollment(for: course.id)
                                }
                            )) {
                                CourseCard(course: courses.first(where: { $0.id == course.id }) ?? course)
                            }
                        }
                    }
                    .refreshable {
                        await loadCourses()
                    }
                }
            }
            .navigationTitle("Academy")
            .task {
                await loadCourses()
                await loadRecurrentNotices()
            }
        }
    }
    
    private func loadCourses() async {
        isLoading = true
        
        // Simulate API call - in production, fetch from backend
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Fixed UUID for demo Amazon Prime Air Operations course (matches badge)
        let amazonPrimeAirCourseId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001") ?? UUID()
        
        // Sample courses data with providers
        courses = [
            // Buzz courses
            TrainingCourse(
                id: UUID(),
                title: "FAA Part 107 Certification Prep",
                description: "Comprehensive course covering all aspects of FAA Part 107 regulations, airspace, weather, and operational safety.",
                duration: "40 hours",
                level: .beginner,
                category: .safety,
                instructor: "John Smith",
                instructorPictureUrl: "https://i.pravatar.cc/150?img=11",
                rating: 4.8,
                studentsCount: 1250,
                isEnrolled: false,
                provider: .buzz,
                badgeId: nil,
                isRecurrent: false,
                recurrentDueDate: nil
            ),
            TrainingCourse(
                id: UUID(),
                title: "Advanced Flight Maneuvers",
                description: "Master complex flight patterns, precision flying, and emergency procedures for professional drone operations.",
                duration: "20 hours",
                level: .advanced,
                category: .operations,
                instructor: "Sarah Johnson",
                instructorPictureUrl: "https://i.pravatar.cc/150?img=47",
                rating: 4.9,
                studentsCount: 890,
                isEnrolled: false,
                provider: .buzz,
                badgeId: nil,
                isRecurrent: false,
                recurrentDueDate: nil
            ),
            TrainingCourse(
                id: UUID(),
                title: "Aerial Photography Mastery",
                description: "Learn composition, lighting, camera settings, and post-processing techniques for stunning aerial photographs.",
                duration: "30 hours",
                level: .intermediate,
                category: .photography,
                instructor: "Mike Chen",
                instructorPictureUrl: "https://i.pravatar.cc/150?img=13",
                rating: 4.7,
                studentsCount: 2100,
                isEnrolled: true,
                provider: .buzz,
                badgeId: nil,
                isRecurrent: false,
                recurrentDueDate: nil
            ),
            // Amazon courses
            TrainingCourse(
                id: amazonPrimeAirCourseId,
                title: "Amazon Prime Air Operations",
                description: "Specialized training for Amazon Prime Air drone delivery operations, safety protocols, and logistics. This course requires recurrent training every year to maintain certification.",
                duration: "25 hours",
                level: .advanced,
                category: .operations,
                instructor: "Amazon Training Team",
                instructorPictureUrl: nil,
                rating: 4.8,
                studentsCount: 3200,
                isEnrolled: true, // Already enrolled and completed
                provider: .amazon,
                badgeId: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002") ?? UUID(), // Demo badge ID
                isRecurrent: true,
                recurrentDueDate: Date().addingTimeInterval(86400 * 7) // Due in 7 days
            ),
            TrainingCourse(
                id: UUID(),
                title: "Amazon Safety & Compliance",
                description: "Amazon-specific safety regulations and compliance requirements for drone operations.",
                duration: "15 hours",
                level: .intermediate,
                category: .safety,
                instructor: "Amazon Safety Division",
                instructorPictureUrl: nil,
                rating: 4.9,
                studentsCount: 2800,
                isEnrolled: false,
                provider: .amazon,
                badgeId: nil,
                isRecurrent: true,
                recurrentDueDate: Calendar.current.date(byAdding: .month, value: 12, to: Date())
            ),
            // T-Mobile courses
            TrainingCourse(
                id: UUID(),
                title: "T-Mobile 5G Network Inspection",
                description: "Learn to inspect and maintain T-Mobile 5G network infrastructure using drones.",
                duration: "18 hours",
                level: .intermediate,
                category: .inspection,
                instructor: "T-Mobile Technical Team",
                instructorPictureUrl: nil,
                rating: 4.7,
                studentsCount: 1500,
                isEnrolled: false,
                provider: .tmobile,
                badgeId: nil,
                isRecurrent: true,
                recurrentDueDate: Calendar.current.date(byAdding: .month, value: 9, to: Date())
            ),
            TrainingCourse(
                id: UUID(),
                title: "T-Mobile Emergency Response",
                description: "Training for emergency response and network restoration using drone technology.",
                duration: "22 hours",
                level: .advanced,
                category: .operations,
                instructor: "T-Mobile Emergency Operations",
                instructorPictureUrl: nil,
                rating: 4.6,
                studentsCount: 980,
                isEnrolled: false,
                provider: .tmobile,
                badgeId: nil,
                isRecurrent: true,
                recurrentDueDate: Calendar.current.date(byAdding: .month, value: 8, to: Date())
            ),
            // Additional Buzz courses
            TrainingCourse(
                id: UUID(),
                title: "Cinematic Drone Videography",
                description: "Create cinematic drone videos with smooth movements, color grading, and professional editing workflows.",
                duration: "35 hours",
                level: .intermediate,
                category: .cinematography,
                instructor: "Emily Davis",
                instructorPictureUrl: "https://i.pravatar.cc/150?img=9",
                rating: 4.9,
                studentsCount: 1560,
                isEnrolled: false,
                provider: .buzz,
                badgeId: nil,
                isRecurrent: false,
                recurrentDueDate: nil
            ),
            TrainingCourse(
                id: UUID(),
                title: "Infrastructure Inspection Techniques",
                description: "Professional inspection methods for bridges, buildings, power lines, and industrial facilities using drones.",
                duration: "25 hours",
                level: .advanced,
                category: .inspection,
                instructor: "Robert Taylor",
                instructorPictureUrl: "https://i.pravatar.cc/150?img=15",
                rating: 4.6,
                studentsCount: 750,
                isEnrolled: false,
                provider: .buzz,
                badgeId: nil,
                isRecurrent: false,
                recurrentDueDate: nil
            ),
            TrainingCourse(
                id: UUID(),
                title: "3D Mapping & Surveying",
                description: "Learn photogrammetry, LiDAR integration, and create accurate 3D models and maps for surveying applications.",
                duration: "28 hours",
                level: .advanced,
                category: .mapping,
                instructor: "Lisa Anderson",
                instructorPictureUrl: "https://i.pravatar.cc/150?img=20",
                rating: 4.8,
                studentsCount: 920,
                isEnrolled: false,
                provider: .buzz,
                badgeId: nil,
                isRecurrent: false,
                recurrentDueDate: nil
            ),
            TrainingCourse(
                id: UUID(),
                title: "Weather & Risk Assessment",
                description: "Understand weather patterns, wind conditions, and risk management for safe drone operations.",
                duration: "15 hours",
                level: .beginner,
                category: .safety,
                instructor: "David Wilson",
                instructorPictureUrl: "https://i.pravatar.cc/150?img=33",
                rating: 4.5,
                studentsCount: 1340,
                isEnrolled: false,
                provider: .buzz,
                badgeId: nil,
                isRecurrent: false,
                recurrentDueDate: nil
            ),
            TrainingCourse(
                id: UUID(),
                title: "Night Operations & Lighting",
                description: "Safe operations after sunset, required lighting, and special considerations for night flights.",
                duration: "12 hours",
                level: .intermediate,
                category: .operations,
                instructor: "Jessica Martinez",
                instructorPictureUrl: "https://i.pravatar.cc/150?img=22",
                rating: 4.7,
                studentsCount: 680,
                isEnrolled: false,
                provider: .buzz,
                badgeId: nil,
                isRecurrent: false,
                recurrentDueDate: nil
            )
        ]
        
        isLoading = false
    }
    
    private func loadRecurrentNotices() async {
        // Find courses that require recurrent training
        let recurrentCourses = courses.filter { $0.isRecurrent && $0.isEnrolled }
        
        recurrentNotices = recurrentCourses.compactMap { course in
            guard let dueDate = course.recurrentDueDate else { return nil }
            
            return RecurrentTrainingNotice(
                id: course.id,
                courseTitle: course.title,
                courseCategory: course.category.rawValue,
                dueDate: dueDate,
                provider: course.provider
            )
        }
    }
}

// MARK: - Provider Chip

struct ProviderChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recurrent Training Card

struct RecurrentTrainingCard: View {
    let notice: RecurrentTrainingNotice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: notice.provider.icon)
                    .foregroundColor(notice.provider.color)
                    .font(.system(size: 20))
                Text(notice.provider.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(notice.provider.color)
                Spacer()
            }
            
            Text(notice.courseTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            HStack {
                Image(systemName: notice.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                    .foregroundColor(notice.urgencyColor)
                    .font(.caption)
                
                if notice.isOverdue {
                    Text("Overdue")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(notice.urgencyColor)
                } else {
                    Text("Due in \(notice.daysUntilDue) days")
                        .font(.caption)
                        .foregroundColor(notice.urgencyColor)
                }
            }
        }
        .padding()
        .frame(width: 200)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notice.urgencyColor.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: notice.urgencyColor.opacity(0.2), radius: 4)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Course Card

struct CourseCard: View {
    let course: TrainingCourse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: course.category.icon)
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text(course.title)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    
                    Text(course.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Provider badge
                    HStack(spacing: 4) {
                        Image(systemName: course.provider.icon)
                            .foregroundColor(course.provider.color)
                            .font(.caption)
                        Text(course.provider.rawValue)
                            .font(.caption)
                            .foregroundColor(course.provider.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(course.provider.color.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                if course.isEnrolled {
                    VStack(spacing: 4) {
                        if course.badgeId != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            Text("Badge")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                            Text("Enrolled")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            HStack(spacing: 16) {
                // Level Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(course.level.color)
                        .frame(width: 8, height: 8)
                    Text(course.level.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(course.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Rating
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", course.rating))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Students Count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(course.studentsCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 4) {
                if let pictureUrl = course.instructorPictureUrl,
                   let url = URL(string: pictureUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 16, height: 16)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 16, height: 16)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Text("Instructor: \(course.instructor)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Course Detail View

struct CourseDetailView: View {
    let course: TrainingCourse
    let onEnrollmentChange: () -> Void
    @State private var isEnrolled: Bool
    @State private var showUnenrollConfirmation = false
    @State private var showCompletionConfirmation = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var badgeService = BadgeService()
    
    init(course: TrainingCourse, onEnrollmentChange: @escaping () -> Void) {
        self.course = course
        self.onEnrollmentChange = onEnrollmentChange
        _isEnrolled = State(initialValue: course.isEnrolled)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Background Image
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: courseBackgroundImageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Color.blue.opacity(0.3)
                                .frame(height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            Color.blue.opacity(0.3)
                                .frame(height: 200)
                        @unknown default:
                            Color.blue.opacity(0.3)
                                .frame(height: 200)
                        }
                    }
                    
                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    
                    // Title overlay
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: course.category.icon)
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                            
                            Spacer()
                            
                            if isEnrolled {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Enrolled")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        Text(course.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Provider badge
                        HStack(spacing: 4) {
                            Image(systemName: course.provider.icon)
                                .foregroundColor(.white)
                                .font(.caption)
                            Text(course.provider.rawValue)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(course.provider.color.opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    Text(course.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Course Info Cards
                    VStack(spacing: 12) {
                        InfoRow(icon: "clock.fill", label: "Duration", value: course.duration)
                        InfoRow(icon: "graduationcap.fill", label: "Level", value: course.level.rawValue)
                        
                        // Provider
                        InfoRow(icon: course.provider.icon, label: "Provider", value: course.provider.rawValue)
                        
                        // Instructor with profile picture
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Instructor")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 8) {
                                if let pictureUrl = course.instructorPictureUrl,
                                   let url = URL(string: pictureUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 32, height: 32)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        case .failure:
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.blue)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue)
                                }
                                Text(course.instructor)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        InfoRow(icon: "star.fill", label: "Rating", value: String(format: "%.1f / 5.0", course.rating))
                        InfoRow(icon: "person.2.fill", label: "Students", value: "\(course.studentsCount)")
                    }
                    .padding(.horizontal)
                    
                    // Badge Status (if course is completed)
                    if let badgeId = course.badgeId {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("Badge Earned")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            Text("You have completed this course and earned a badge.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Recurrent Training Notice
                    if course.isRecurrent, let dueDate = course.recurrentDueDate {
                        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                        let isUrgent = daysUntilDue <= 7
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: isUrgent ? "exclamationmark.triangle.fill" : "clock.fill")
                                    .foregroundColor(isUrgent ? .red : .orange)
                                Text("Recurrent Training Required")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isUrgent ? .red : .orange)
                            }
                            
                            if course.badgeId != nil {
                                // Badge expiration warning
                                if daysUntilDue <= 7 && daysUntilDue > 0 {
                                    Text("⚠️ Your badge will expire in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s"). Complete the recurrent training to renew your badge.")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                } else if daysUntilDue <= 0 {
                                    Text("⚠️ Your badge has expired. Complete the recurrent training to renew it.")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            } else {
                                Text("This course requires periodic recurrent training. Next due: \(dueDate, style: .date)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background((isUrgent ? Color.red : Color.orange).opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Enroll/Unenroll/Complete/Renew Button
                    if isEnrolled {
                        VStack(spacing: 12) {
                            if course.badgeId != nil {
                                // Course already completed
                                if course.isRecurrent {
                                    // Show renew badge button for recurrent courses
                                    CustomButton(
                                        title: "Renew Badge",
                                        action: {
                                            // Navigate to course content for renewal
                                        },
                                        isDisabled: false
                                    )
                                } else {
                                    CustomButton(
                                        title: "View Course Materials",
                                        action: {
                                            // Navigate to course content (future implementation)
                                        },
                                        isDisabled: false
                                    )
                                }
                            } else {
                                // Enrolled but not completed
                                CustomButton(
                                    title: "Continue Learning",
                                    action: {
                                        // Navigate to course content (future implementation)
                                    },
                                    isDisabled: false
                                )
                                
                                Button(action: {
                                    showCompletionConfirmation = true
                                }) {
                                    Text("Mark as Completed")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                            
                            Button(action: {
                                showUnenrollConfirmation = true
                            }) {
                                Text("Unenroll from Course")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        CustomButton(
                            title: "Enroll Now",
                            action: {
                                isEnrolled = true
                                onEnrollmentChange()
                            },
                            isDisabled: false
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Course Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unenroll from Course", isPresented: $showUnenrollConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Unenroll", role: .destructive) {
                isEnrolled = false
                onEnrollmentChange()
                // Dismiss after unenrolling
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to unenroll from \"\(course.title)\"? You will lose access to course materials and progress.")
        }
        .alert("Complete Course", isPresented: $showCompletionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Complete", role: .none) {
                Task {
                    await completeCourse()
                }
            }
        } message: {
            Text("Mark \"\(course.title)\" as completed? You will earn a badge for this achievement.")
        }
    }
    
    private func completeCourse() async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await badgeService.awardBadge(
                pilotId: currentUser.id,
                courseId: course.id,
                courseTitle: course.title,
                courseCategory: course.category.rawValue,
                provider: Badge.CourseProvider(rawValue: course.provider.rawValue) ?? .buzz
            )
            
            // Show success message
            showCompletionConfirmation = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        } catch {
            print("Error awarding badge: \(error)")
        }
    }
    
    private var courseBackgroundImageUrl: String {
        // Return relevant background images based on course category
        switch course.category {
        case .safety:
            return "https://images.unsplash.com/photo-1518611012118-696072aa971a?w=800&h=400&fit=crop"
        case .operations:
            return "https://images.unsplash.com/photo-1473968512647-3e447244af8f?w=800&h=400&fit=crop"
        case .photography:
            return "https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=800&h=400&fit=crop"
        case .cinematography:
            return "https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=800&h=400&fit=crop"
        case .inspection:
            return "https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800&h=400&fit=crop"
        case .mapping:
            return "https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&h=400&fit=crop"
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

