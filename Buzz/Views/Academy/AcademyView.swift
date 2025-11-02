//
//  AcademyView.swift
//  Buzz
//
//  Created by Xinyu Fang on 11/1/25.
//

import SwiftUI

struct TrainingCourse: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let duration: String
    let level: CourseLevel
    let category: CourseCategory
    let instructor: String
    let rating: Double
    let studentsCount: Int
    var isEnrolled: Bool
    
    enum CourseLevel: String {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        
        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }
    }
    
    enum CourseCategory: String {
        case safety = "Safety & Regulations"
        case operations = "Flight Operations"
        case photography = "Aerial Photography"
        case cinematography = "Cinematography"
        case inspection = "Inspections"
        case mapping = "Mapping & Surveying"
        
        var icon: String {
            switch self {
            case .safety: return "shield.fill"
            case .operations: return "airplane.departure"
            case .photography: return "camera.fill"
            case .cinematography: return "video.fill"
            case .inspection: return "magnifyingglass"
            case .mapping: return "map.fill"
            }
        }
    }
}

struct AcademyView: View {
    @State private var selectedCategory: TrainingCourse.CourseCategory? = nil
    @State private var courses: [TrainingCourse] = []
    @State private var isLoading = false
    
    func toggleEnrollment(for courseId: UUID) {
        if let index = courses.firstIndex(where: { $0.id == courseId }) {
            courses[index].isEnrolled.toggle()
        }
    }
    
    private let allCategories: [TrainingCourse.CourseCategory] = [
        .safety, .operations, .photography, .cinematography, .inspection, .mapping
    ]
    
    var filteredCourses: [TrainingCourse] {
        if let category = selectedCategory {
            return courses.filter { $0.category == category }
        }
        return courses
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                                course: course,
                                onEnrollmentChange: { toggleEnrollment(for: course.id) }
                            )) {
                                CourseCard(course: course)
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
            }
        }
    }
    
    private func loadCourses() async {
        isLoading = true
        
        // Simulate API call - in production, fetch from backend
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Sample courses data
        courses = [
            TrainingCourse(
                title: "FAA Part 107 Certification Prep",
                description: "Comprehensive course covering all aspects of FAA Part 107 regulations, airspace, weather, and operational safety.",
                duration: "40 hours",
                level: .beginner,
                category: .safety,
                instructor: "John Smith",
                rating: 4.8,
                studentsCount: 1250,
                isEnrolled: false
            ),
            TrainingCourse(
                title: "Advanced Flight Maneuvers",
                description: "Master complex flight patterns, precision flying, and emergency procedures for professional drone operations.",
                duration: "20 hours",
                level: .advanced,
                category: .operations,
                instructor: "Sarah Johnson",
                rating: 4.9,
                studentsCount: 890,
                isEnrolled: false
            ),
            TrainingCourse(
                title: "Aerial Photography Mastery",
                description: "Learn composition, lighting, camera settings, and post-processing techniques for stunning aerial photographs.",
                duration: "30 hours",
                level: .intermediate,
                category: .photography,
                instructor: "Mike Chen",
                rating: 4.7,
                studentsCount: 2100,
                isEnrolled: true
            ),
            TrainingCourse(
                title: "Cinematic Drone Videography",
                description: "Create cinematic drone videos with smooth movements, color grading, and professional editing workflows.",
                duration: "35 hours",
                level: .intermediate,
                category: .cinematography,
                instructor: "Emily Davis",
                rating: 4.9,
                studentsCount: 1560,
                isEnrolled: false
            ),
            TrainingCourse(
                title: "Infrastructure Inspection Techniques",
                description: "Professional inspection methods for bridges, buildings, power lines, and industrial facilities using drones.",
                duration: "25 hours",
                level: .advanced,
                category: .inspection,
                instructor: "Robert Taylor",
                rating: 4.6,
                studentsCount: 750,
                isEnrolled: false
            ),
            TrainingCourse(
                title: "3D Mapping & Surveying",
                description: "Learn photogrammetry, LiDAR integration, and create accurate 3D models and maps for surveying applications.",
                duration: "28 hours",
                level: .advanced,
                category: .mapping,
                instructor: "Lisa Anderson",
                rating: 4.8,
                studentsCount: 920,
                isEnrolled: false
            ),
            TrainingCourse(
                title: "Weather & Risk Assessment",
                description: "Understand weather patterns, wind conditions, and risk management for safe drone operations.",
                duration: "15 hours",
                level: .beginner,
                category: .safety,
                instructor: "David Wilson",
                rating: 4.5,
                studentsCount: 1340,
                isEnrolled: false
            ),
            TrainingCourse(
                title: "Night Operations & Lighting",
                description: "Safe operations after sunset, required lighting, and special considerations for night flights.",
                duration: "12 hours",
                level: .intermediate,
                category: .operations,
                instructor: "Jessica Martinez",
                rating: 4.7,
                studentsCount: 680,
                isEnrolled: false
            )
        ]
        
        isLoading = false
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
                }
                
                Spacer()
                
                if course.isEnrolled {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                        Text("Enrolled")
                            .font(.caption2)
                            .foregroundColor(.green)
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
            
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
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
    @State private var isEnrolled = false
    @State private var showUnenrollConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: course.category.icon)
                            .foregroundColor(.blue)
                            .font(.system(size: 32))
                        
                        Spacer()
                        
                        if isEnrolled {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Enrolled")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Text(course.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(course.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Course Info Cards
                VStack(spacing: 12) {
                    InfoRow(icon: "clock.fill", label: "Duration", value: course.duration)
                    InfoRow(icon: "graduationcap.fill", label: "Level", value: course.level.rawValue)
                    InfoRow(icon: "person.circle.fill", label: "Instructor", value: course.instructor)
                    InfoRow(icon: "star.fill", label: "Rating", value: String(format: "%.1f / 5.0", course.rating))
                    InfoRow(icon: "person.2.fill", label: "Students", value: "\(course.studentsCount)")
                }
                .padding(.horizontal)
                
                // Enroll/Unenroll Button
                if isEnrolled {
                    VStack(spacing: 12) {
                        CustomButton(
                            title: "Continue Learning",
                            action: {
                                // Navigate to course content (future implementation)
                            },
                            isDisabled: false
                        )
                        
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
            .padding(.vertical)
        }
        .navigationTitle("Course Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isEnrolled = course.isEnrolled
        }
        .alert("Unenroll from Course", isPresented: $showUnenrollConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Unenroll", role: .destructive) {
                isEnrolled = false
                onEnrollmentChange()
            }
        } message: {
            Text("Are you sure you want to unenroll from \"\(course.title)\"? You will lose access to course materials and progress.")
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

