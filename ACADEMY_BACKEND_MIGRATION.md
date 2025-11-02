# Academy Backend Migration Guide

## Current Implementation

The sample courses are currently **hardcoded** in `AcademyView.swift` in the `loadCourses()` function (lines 143-239). This is perfect for demo purposes but needs to be migrated to a backend database for production.

## Location of Sample Data

**File:** `Buzz/Views/Academy/AcademyView.swift`
**Function:** `loadCourses()` (lines 143-239)
**Current Behavior:** 
- Simulates API call with 0.5 second delay
- Returns hardcoded array of 8 sample courses

## Migration Steps

### 1. Database Setup

Run the SQL script `database_academy.sql` in your Supabase SQL Editor to create:
- `training_courses` table - stores all available courses
- `course_enrollments` table - tracks which pilots are enrolled in which courses

### 2. Update TrainingCourse Model

The `TrainingCourse` struct in `AcademyView.swift` needs to conform to `Codable` for database mapping. Make sure it matches the database schema:

```swift
struct TrainingCourse: Identifiable, Codable {
    var id: UUID
    let title: String
    let description: String
    let duration: String
    let level: CourseLevel
    let category: CourseCategory
    let instructor: String
    let rating: Double
    let studentsCount: Int
    var isEnrolled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case duration
        case level
        case category
        case instructor
        case rating
        case studentsCount = "students_count"
        case isEnrolled // This won't come from DB, will be computed
    }
}
```

### 3. Use AcademyService

A new `AcademyService.swift` has been created following the same pattern as `BookingService` and `RankingService`. 

**Replace the current `loadCourses()` in `AcademyView.swift`:**

```swift
// OLD (hardcoded):
private func loadCourses() async {
    isLoading = true
    try? await Task.sleep(nanoseconds: 500_000_000)
    courses = [ /* hardcoded courses */ ]
    isLoading = false
}

// NEW (backend):
@StateObject private var academyService = AcademyService()

private func loadCourses() async {
    guard let currentUser = authService.currentUser else { return }
    do {
        try await academyService.fetchCoursesWithEnrollment(pilotId: currentUser.id)
        courses = academyService.courses
    } catch {
        print("Error loading courses: \(error)")
    }
}
```

### 4. Update Enrollment Functions

**Replace `toggleEnrollment()` in `AcademyView.swift`:**

```swift
// OLD:
func toggleEnrollment(for courseId: UUID) {
    if let index = courses.firstIndex(where: { $0.id == courseId }) {
        courses[index].isEnrolled.toggle()
    }
}

// NEW:
func toggleEnrollment(for courseId: UUID, enroll: Bool) async {
    guard let currentUser = authService.currentUser else { return }
    do {
        if enroll {
            try await academyService.enrollInCourse(pilotId: currentUser.id, courseId: courseId)
        } else {
            try await academyService.unenrollFromCourse(pilotId: currentUser.id, courseId: courseId)
        }
        // Refresh courses to get updated state
        try await academyService.fetchCoursesWithEnrollment(pilotId: currentUser.id)
        courses = academyService.courses
    } catch {
        print("Error toggling enrollment: \(error)")
    }
}
```

**Update `CourseDetailView` enrollment actions:**

```swift
// In CourseDetailView, update the enroll/unenroll actions:
CustomButton(
    title: "Enroll Now",
    action: {
        Task {
            await onEnrollmentChange(true) // Pass true for enroll
        }
    }
)

Button(action: {
    showUnenrollConfirmation = true
}) {
    // ...
}
.alert("Unenroll from Course", isPresented: $showUnenrollConfirmation) {
    Button("Unenroll", role: .destructive) {
        Task {
            await onEnrollmentChange(false) // Pass false for unenroll
        }
    }
}
```

### 5. Update Navigation Link

**Update the callback signature:**

```swift
NavigationLink(destination: CourseDetailView(
    course: courses.first(where: { $0.id == course.id }) ?? course,
    onEnrollmentChange: { enroll in
        await toggleEnrollment(for: course.id, enroll: enroll)
    }
)) {
    CourseCard(course: courses.first(where: { $0.id == course.id }) ?? course)
}
```

## Files Created

1. **`Buzz/Services/AcademyService.swift`** - Service for fetching courses and managing enrollments
2. **`database_academy.sql`** - Database schema and sample data

## Benefits of Backend Migration

1. **Dynamic Content**: Admins can add/edit courses without app updates
2. **User-Specific Data**: Enrollment status persists across devices
3. **Analytics**: Track course popularity, completion rates, etc.
4. **Progress Tracking**: Store course progress, completion status
5. **Scalability**: Easy to add more courses without code changes

## Testing Checklist

- [ ] Database tables created successfully
- [ ] Sample courses inserted into database
- [ ] `AcademyService` fetches courses correctly
- [ ] Enrollment status loads correctly for logged-in pilots
- [ ] Enroll action creates enrollment record
- [ ] Unenroll action deletes enrollment record
- [ ] Course list updates after enrollment changes
- [ ] RLS policies prevent unauthorized access

## Notes

- The `isEnrolled` property is computed from the `course_enrollments` table, not stored directly in `training_courses`
- RLS policies ensure pilots can only see/modify their own enrollments
- Consider adding admin interface for course management in the future
- You may want to add course content/videos tables for actual course materials

