# UAS Pilot Course Implementation

## Overview
This document describes the implementation of the UAS Pilot Course feature, including backend database setup, course content structure, and UI components.

## Database Changes

### Migration File: `create_uas_pilot_course_migration.sql`

#### 1. Added Provider Field to `training_courses`
- Added `provider` column (Buzz, Amazon, T-Mobile, Other)
- Added `instructor_picture_url` column

#### 2. Created `course_units` Table
- Stores individual course units with:
  - `unit_number`: Sequential unit number (1-20)
  - `title`: Unit title
  - `description`: Unit description
  - `content`: Course material content (markdown/HTML)
  - `step_number`: Which step the unit belongs to (1, 2, or 3)
  - `is_mandatory`: Boolean flag for mandatory units
  - `order_index`: Ordering within the course

#### 3. Dynamic Students Count
- Created trigger `update_course_students_count()` that automatically updates `students_count` when enrollments change
- Trigger fires on INSERT/DELETE from `course_enrollments` table

#### 4. UAS Pilot Course Data
- **Course Details:**
  - Title: "UAS Pilot Course"
  - Provider: Buzz
  - Instructor: Buzz
  - Rating: 4.95
  - Students: 0 (dynamically updated)
  - Duration: 120 hours
  - Level: Beginner
  - Category: Flight Operations

- **Course Structure:**
  - **Mandatory Units (3):**
    - UNIT 1 - GROUND SCHOOL
    - UNIT 2 - HEALTH & SAFETY
    - UNIT 3 - OPERATIONS
  
  - **Step 1: Pick a Base Program (2 units):**
    - UNIT 4 - DRONE PILOT
    - UNIT 5 - CAMERA/PAYLOAD OPERATOR
  
  - **Step 2: Extension Courses (7 units):**
    - UNIT 6 - DRONE BUSINESS
    - UNIT 7 - FILM & AERIAL CINEMATOGRAPHY
    - UNIT 8 - POST PRODUCTION
    - UNIT 9 - REAL ESTATE
    - UNIT 10 - MAPPING & SURVEYING
    - UNIT 11 - INSPECTIONS
    - UNIT 12 - SEARCH & RESCUE
  
  - **Step 3: Further Your Base Training (8 units):**
    - UNIT 13 - INTERMEDIATE DRONE PILOT
    - UNIT 14 - INTERMEDIATE CAMERA/PAYLOAD OPERATOR
    - UNIT 15 - ADVANCED DRONE PILOT
    - UNIT 16 - ADVANCED CAMERA/PAYLOAD OPERATOR
    - UNIT 17 - SPECIALIZED SEARCH & RESCUE W/ THERMOGRAPHY
    - UNIT 18 - SPECIALIZED POST PRODUCTION
    - UNIT 19 - DRONE REPAIR TECHNICIAN/ENGR
    - UNIT 20 - PUBLIC SAFETY PILOT

## Code Changes

### 1. New Models

#### `CourseUnit.swift`
- Model representing a course unit
- Includes all fields from database schema
- Codable for JSON parsing

### 2. Updated Services

#### `AcademyService.swift`
- **`fetchCourses()`**: Fetches all courses from backend
- **`fetchCoursesWithEnrollment(pilotId:)`**: Fetches courses with enrollment status for a specific pilot
- **`fetchCourseUnits(courseId:)`**: Fetches all units for a course
- **`enrollInCourse(pilotId:courseId:)`**: Enrolls pilot in course and refreshes course list
- Added `TrainingCourseResponse` and `CourseEnrollmentResponse` models for API responses

### 3. Updated Views

#### `AcademyView.swift`
- Updated `loadCourses()` to fetch from backend when demo mode is disabled
- Uses `AcademyService.fetchCoursesWithEnrollment()` for authenticated users

#### `CourseDetailView` (in AcademyView.swift)
- Updated "Enroll Now" button to navigate to `CourseContentView`
- Updated "Continue Learning" button to navigate to `CourseContentView`
- Updated "View Course Materials" and "Renew Badge" buttons to navigate to `CourseContentView`
- Enrollment now calls backend service

### 4. New Views

#### `CourseContentView.swift`
- Displays course structure with all units organized by:
  - Mandatory Units section
  - Step 1: Pick a Base Program (red badge)
  - Step 2: Extension Courses (blue badge)
  - Step 3: Further Your Base Training (black badge)
- Each unit is tappable and navigates to `UnitDetailView`
- Fetches units from backend using `AcademyService.fetchCourseUnits()`

#### `UnitDetailView.swift`
- Displays individual unit details:
  - Unit number badge
  - Unit title
  - Mandatory indicator (if applicable)
  - Description
  - Course material content (or placeholder)
  - Course info footer

## User Flow

1. **Browse Courses**: User sees UAS Pilot Course in Academy view
2. **View Course Details**: Tap course to see details (instructor: Buzz, rating: 4.95, students: dynamically updated)
3. **Enroll**: Tap "Enroll Now" → Navigates to Course Content view
4. **View Course Structure**: See all units organized by steps
5. **Access Unit Material**: Tap any unit → Navigate to Unit Detail view
6. **View Unit Content**: See unit-specific course material

## Backend Integration

### Production Mode (Demo Mode OFF)
- All courses fetched from Supabase `training_courses` table
- Course units fetched from `course_units` table
- Enrollment creates record in `course_enrollments` table
- Students count automatically updated via database trigger

### Demo Mode (Demo Mode ON)
- Uses hardcoded demo courses (existing behavior)
- UAS Pilot Course not shown in demo mode

## Database Setup Instructions

1. Run the migration SQL file in Supabase SQL Editor:
   ```sql
   -- Run create_uas_pilot_course_migration.sql
   ```

2. Verify the course was created:
   ```sql
   SELECT * FROM training_courses WHERE title = 'UAS Pilot Course';
   ```

3. Verify units were created:
   ```sql
   SELECT COUNT(*) FROM course_units WHERE course_id = (
       SELECT id FROM training_courses WHERE title = 'UAS Pilot Course'
   );
   -- Should return 20
   ```

## Testing Checklist

- [ ] UAS Pilot Course appears in Academy view (when demo mode is OFF)
- [ ] Course shows correct details (Buzz provider, 4.95 rating, 0 students initially)
- [ ] Students count updates when pilot enrolls
- [ ] "Enroll Now" navigates to Course Content view
- [ ] Course Content shows all 20 units organized correctly
- [ ] Mandatory units section displays UNIT 1-3
- [ ] Step 1 shows UNIT 4-5 with red badge
- [ ] Step 2 shows UNIT 6-12 with blue badge
- [ ] Step 3 shows UNIT 13-20 with black badge
- [ ] Tapping a unit navigates to Unit Detail view
- [ ] Unit Detail view shows unit information
- [ ] Enrollment creates record in database
- [ ] Students count increments after enrollment

## Future Enhancements

- Add unit completion tracking
- Add progress indicators for each unit
- Add quizzes/assessments per unit
- Add video content support
- Add unit prerequisites
- Add certificate generation upon course completion

