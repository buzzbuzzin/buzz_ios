# Course Content Architecture

This document explains how course information is fetched from the backend and displayed in the Buzz iOS app. It covers the database schema, Swift models, services, and views involved in rendering course content.

---

## Table of Contents

1. [Overview](#overview)
2. [Database Schema](#database-schema)
3. [Swift Models](#swift-models)
4. [Services](#services)
5. [Data Flow](#data-flow)
6. [View Components](#view-components)
7. [Section Types](#section-types)
8. [Lock States and Prerequisites](#lock-states-and-prerequisites)
9. [Fallback Mechanisms](#fallback-mechanisms)
10. [Adding New Content](#adding-new-content)

---

## Overview

The course content system follows a **section-based architecture** where:

- **Courses** (`training_courses`) contain multiple **Sections** (`course_sections`)
- **Sections** contain multiple **Units** (`course_units`)
- Sections can have different types: `units`, `test`, `recurrent`, `exam`
- Access to sections/units is controlled by **subscription status** and **test completion**

```
┌─────────────────────────────────────────────────────────────┐
│                     TrainingCourse                          │
│  (e.g., "UAS Pilot Course")                                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Section 1: MANDATORY UNITS (type: units)            │   │
│  │   └── Unit 1, Unit 2, Unit 3                        │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ Section 2: GROUND SCHOOL TEST (type: test)          │   │
│  │   └── [In-app test UI]                              │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ Section 3: BASE PROGRAM (type: units)               │   │
│  │   └── Unit 4                                        │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ Section 4: FLIGHT REVIEW (type: exam)               │   │
│  │   └── [Links to Test Center - flight_review]        │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ Section 5: RADIO OPERATOR (type: exam)              │   │
│  │   └── [Links to Test Center - roc_a]                │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ Section 6: RECURRENT TRAINING (type: recurrent)     │   │
│  │   └── [Special recurrent training UI]               │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ Section 7: EXTENSION COURSES (type: units)          │   │
│  │   └── Unit 5, Unit 6, Unit 7...                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Database Schema

### `training_courses` Table

The main course table containing course metadata.

```sql
CREATE TABLE public.training_courses (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  description text NOT NULL,
  duration text NOT NULL,
  level text NOT NULL,  -- 'Beginner', 'Intermediate', 'Advanced'
  category text NOT NULL,
  instructor text NOT NULL,
  instructor_picture_url text,
  rating double precision DEFAULT 0.0,
  students_count integer DEFAULT 0,
  provider text DEFAULT 'Buzz',  -- 'Buzz', 'Amazon', 'T-Mobile', 'Other'
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT training_courses_pkey PRIMARY KEY (id)
);
```

### `course_sections` Table

Defines the sections within a course.

```sql
CREATE TABLE public.course_sections (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,                     -- Foreign key to training_courses
  name text NOT NULL,                          -- Display name (e.g., "MANDATORY UNITS")
  display_order integer NOT NULL,              -- Order in which sections appear
  description text,                            -- Optional description
  section_type text DEFAULT 'units',           -- 'units', 'test', 'recurrent', 'exam'
  requires_subscription boolean DEFAULT false, -- Whether subscription is needed
  requires_test_passed boolean DEFAULT false,  -- Whether Ground School Test must be passed
  prerequisite_section_id uuid,                -- Optional: section that must be completed first
  is_active boolean DEFAULT true,              -- Whether section is visible
  exam_type text,                              -- For 'exam' sections: 'flight_review' or 'roc_a'
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT course_sections_pkey PRIMARY KEY (id),
  CONSTRAINT course_sections_course_id_fkey FOREIGN KEY (course_id) 
    REFERENCES public.training_courses(id) ON DELETE CASCADE
);
```

### `course_units` Table

Contains the actual course content units.

```sql
CREATE TABLE public.course_units (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,                     -- Foreign key to training_courses
  unit_number integer NOT NULL,                -- Display number (1, 2, 3...)
  title text NOT NULL,
  description text,
  content text,
  section_id uuid,                             -- NEW: Reference to course_sections
  step_number integer,                         -- DEPRECATED: Use section_id instead
  is_mandatory boolean DEFAULT false,          -- DEPRECATED: Use section_id instead
  order_index integer NOT NULL,                -- Sort order within section
  pdf_url jsonb,                               -- Array of PDF URLs for course materials
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT course_units_pkey PRIMARY KEY (id),
  CONSTRAINT course_units_course_id_fkey FOREIGN KEY (course_id) 
    REFERENCES public.training_courses(id),
  CONSTRAINT course_units_section_id_fkey FOREIGN KEY (section_id) 
    REFERENCES public.course_sections(id) ON DELETE SET NULL
);
```

### Important UUIDs

The UAS Pilot Course uses fixed UUIDs for easy reference:

| Entity | UUID |
|--------|------|
| UAS Pilot Course | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| Mandatory Units Section | `00000001-0000-0000-0000-000000000001` |
| Ground School Test Section | `00000002-0000-0000-0000-000000000002` |
| Base Program Section | `00000003-0000-0000-0000-000000000003` |
| Recurrent Training Section | `00000004-0000-0000-0000-000000000004` |
| Extension Courses Section | `00000005-0000-0000-0000-000000000005` |
| Further Training Section | `00000006-0000-0000-0000-000000000006` |
| Flight Review Section | `00000007-0000-0000-0000-000000000007` |
| Radio Operator Section | `00000008-0000-0000-0000-000000000008` |

---

## Swift Models

### `CourseSection` Model

**File:** `Buzz/Models/CourseSection.swift`

```swift
struct CourseSection: Identifiable, Codable {
    let id: UUID
    let courseId: UUID
    let name: String
    let displayOrder: Int
    let description: String?
    let sectionType: String      // 'units', 'test', 'recurrent', 'exam'
    let requiresSubscription: Bool
    let requiresTestPassed: Bool
    let prerequisiteSectionId: UUID?
    let isActive: Bool
    let examType: String?        // For 'exam' sections: 'flight_review' or 'roc_a'
}
```

**Key Properties:**
- `sectionType`: Determines how the section is rendered (see [Section Types](#section-types))
- `requiresSubscription`: If `true`, units in this section need Academy Pass subscription
- `requiresTestPassed`: If `true`, user must pass Ground School Test to access
- `examType`: For `exam` type sections, links to Test Center exam type

### `CourseUnit` Model

**File:** `Buzz/Models/CourseUnit.swift`

```swift
struct CourseUnit: Identifiable, Codable {
    let id: UUID
    let courseId: UUID
    let unitNumber: Int
    let title: String
    let description: String?
    let content: String?
    let pdfUrls: [String]        // Array of PDF URLs
    let sectionId: UUID?         // NEW: Reference to course_sections
    let stepNumber: Int?         // DEPRECATED
    let isMandatory: Bool        // DEPRECATED
    let orderIndex: Int          // Sort order within section
}
```

**Key Properties:**
- `sectionId`: Links unit to its parent section (preferred method)
- `stepNumber` / `isMandatory`: Legacy fields for backward compatibility
- `pdfUrls`: Contains URLs to PDF course materials (can be multiple per unit)

---

## Services

### `AcademyService`

**File:** `Buzz/Services/AcademyService.swift`

The main service for fetching course data from Supabase.

#### Key Methods

```swift
// Fetch all sections for a course (ordered by display_order)
func fetchCourseSections(courseId: UUID) async throws -> [CourseSection]

// Fetch all units for a course (ordered by order_index)
func fetchCourseUnits(courseId: UUID) async throws -> [CourseUnit]

// Check if user passed Ground School Test
func checkGroundSchoolTestStatus(pilotId: UUID, courseId: UUID) async throws -> Bool
```

#### Example: Fetching Sections

```swift
let sections = try await supabase
    .from("course_sections")
    .select()
    .eq("course_id", value: courseId.uuidString)
    .eq("is_active", value: true)
    .order("display_order", ascending: true)
    .execute()
    .value
```

---

## Data Flow

### Loading Course Content

```
┌──────────────────────────────────────────────────────────────────────┐
│                        CourseContentView                              │
│                                                                       │
│  1. User navigates to course                                         │
│                     ↓                                                 │
│  2. loadSectionsAndUnits() called in .task {}                        │
│                     ↓                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  3. Fetch sections from database                                 │ │
│  │     academyService.fetchCourseSections(courseId: course.id)     │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                     ↓                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  4. Fetch all units for the course                              │ │
│  │     academyService.fetchCourseUnits(courseId: course.id)        │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                     ↓                                                 │
│  5. Group units by section_id into unitsBySection dictionary         │
│                     ↓                                                 │
│  6. Handle fallback for courses without sections                     │
│                     ↓                                                 │
│  7. Check subscription status (StoreKitManager)                      │
│                     ↓                                                 │
│  8. Check Ground School Test status                                  │
│                     ↓                                                 │
│  9. Render ForEach(sections) { DynamicSectionView(...) }            │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### Code: Loading Sections and Units

```swift
private func loadSectionsAndUnits() async {
    isLoading = true
    
    do {
        // 1. Fetch sections from database
        let dbSections = try await academyService.fetchCourseSections(courseId: course.id)
        
        // 2. Fetch all units for the course
        let allUnits = try await academyService.fetchCourseUnits(courseId: course.id)
        
        // 3. Check if course has sections defined
        if dbSections.isEmpty && !allUnits.isEmpty {
            // FALLBACK: Create legacy sections from step_number/is_mandatory
            let (fallbackSections, fallbackGrouped) = createLegacySections(from: allUnits)
            sections = fallbackSections
            unitsBySection = fallbackGrouped
        } else {
            // 4. Group units by section_id
            sections = dbSections
            var grouped: [UUID: [CourseUnit]] = [:]
            
            for unit in allUnits {
                if let sectionId = unit.sectionId {
                    grouped[sectionId, default: []].append(unit)
                } else {
                    // Handle units without section_id
                    assignUnassignedUnits([unit], to: &grouped, sections: sections)
                }
            }
            unitsBySection = grouped
        }
    } catch {
        errorMessage = error.localizedDescription
    }
    
    isLoading = false
}
```

---

## View Components

### Component Hierarchy

```
CourseContentView
├── Course Header (title, description)
└── ForEach(sections)
    └── DynamicSectionView
        ├── case "test" → GroundSchoolTestSectionContent
        ├── case "exam" → TestCenterExamSectionView
        ├── case "recurrent" → RecurrentTrainingSectionContent
        └── default → DynamicUnitsSectionView
                        └── ForEach(units)
                            └── UnitRow
```

### `DynamicSectionView`

The main component that renders sections based on their `section_type`:

```swift
struct DynamicSectionView: View {
    let section: CourseSection
    let units: [CourseUnit]
    let course: TrainingCourse
    let hasSubscription: Bool
    let hasPassedTest: Bool
    let onSubscribe: () -> Void
    let onNavigateToTest: () -> Void
    
    var body: some View {
        switch section.sectionType {
        case "test":
            // Ground School Test UI
            GroundSchoolTestSectionContent(...)
            
        case "exam":
            // Test Center exam link (Flight Review, ROC-A)
            TestCenterExamSectionView(...)
            
        case "recurrent":
            // Recurrent Training UI
            RecurrentTrainingSectionContent(...)
            
        default:
            // Regular units list
            DynamicUnitsSectionView(...)
        }
    }
}
```

### `UnitRow`

Displays a single unit with lock state:

```swift
struct UnitRow: View {
    let unit: CourseUnit
    var isLocked: Bool = false
    var lockReason: String = "Subscribe to unlock"
    
    // Displays:
    // - Unit number badge (or lock icon if locked)
    // - Title and description
    // - Lock reason if locked
    // - Chevron for navigation
}
```

---

## Section Types

| Type | Description | UI Component | Example |
|------|-------------|--------------|---------|
| `units` | Contains course units | `DynamicUnitsSectionView` | MANDATORY UNITS, BASE PROGRAM |
| `test` | Ground School Test | `GroundSchoolTestSectionContent` | GROUND SCHOOL TEST |
| `recurrent` | Recurrent training | `RecurrentTrainingSectionContent` | RECURRENT TRAINING |
| `exam` | Test Center exam link | `TestCenterExamSectionView` | FLIGHT REVIEW, RADIO OPERATOR |

### Adding a New Section Type

1. Add the new type to the switch statement in `DynamicSectionView`
2. Create a new view component for the section type
3. Update the database `section_type` constraint if needed

---

## Lock States and Prerequisites

### Lock Determination

Sections and units can be locked based on:

1. **Test Requirement** (`requiresTestPassed: true`): User must pass Ground School Test
2. **Subscription Requirement** (`requiresSubscription: true`): User needs Academy Pass

```swift
// In DynamicUnitsSectionView
private func getLockStatus(for unit: CourseUnit) -> (isLocked: Bool, lockReason: String, requiresAction: LockAction) {
    let needsTest = section.requiresTestPassed && !hasPassedTest
    let needsSubscription = section.requiresSubscription && !hasSubscription
    
    if needsTest && needsSubscription {
        return (true, "Pass Ground School Test & Subscribe to unlock", .subscribe)
    } else if needsTest {
        return (true, "Complete Ground School Test to unlock", .test)
    } else if needsSubscription {
        return (true, "Subscribe to unlock", .subscribe)
    }
    
    return (false, "", .none)
}
```

### Lock States Table

| Section | requires_subscription | requires_test_passed | Result |
|---------|----------------------|---------------------|--------|
| MANDATORY UNITS | false | false | Always unlocked |
| GROUND SCHOOL TEST | false | false | Always accessible |
| BASE PROGRAM | false | true | Unlocked after test |
| FLIGHT REVIEW | false | true | Unlocked after test |
| RADIO OPERATOR | false | true | Unlocked after test |
| RECURRENT TRAINING | true | true | Needs test + subscription |
| EXTENSION COURSES | true | true | Needs test + subscription |

---

## Fallback Mechanisms

### For Courses Without Database Sections

If a course has units but no sections defined in `course_sections`, the app creates **legacy sections** based on the deprecated `step_number` and `is_mandatory` fields:

```swift
private func createLegacySections(from units: [CourseUnit]) -> ([CourseSection], [UUID: [CourseUnit]]) {
    // Separate units by legacy fields
    let mandatoryUnits = units.filter { $0.isMandatory }
    let step1Units = units.filter { !$0.isMandatory && $0.stepNumber == 1 }
    let step2Units = units.filter { !$0.isMandatory && $0.stepNumber == 2 }
    let step3Units = units.filter { !$0.isMandatory && $0.stepNumber == 3 }
    
    // Create sections programmatically
    // ... creates MANDATORY UNITS, BASE PROGRAM, EXTENSION COURSES, etc.
}
```

### For Units Without `section_id`

Units with `null` section_id are assigned to sections based on their legacy fields:

```swift
private func assignUnassignedUnits(_ units: [CourseUnit], to grouped: inout [UUID: [CourseUnit]], sections: [CourseSection]) {
    for unit in units {
        if unit.isMandatory {
            // Assign to MANDATORY UNITS section
        } else if let stepNumber = unit.stepNumber {
            // Assign based on step_number
        } else {
            // Fallback to first 'units' section
        }
    }
}
```

---

## Adding New Content

### Adding a New Unit

```sql
INSERT INTO public.course_units (
    course_id,
    unit_number,
    title,
    description,
    section_id,
    order_index,
    pdf_url
)
VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',  -- UAS Pilot Course
    12,                                        -- Unit number
    'New Unit Title',
    'Unit description',
    '00000005-0000-0000-0000-000000000005',  -- Extension Courses section
    120,                                       -- Order index (higher = later)
    '["https://example.com/unit12.pdf"]'      -- PDF URLs as JSON array
);
```

### Adding a New Section

```sql
INSERT INTO public.course_sections (
    course_id,
    name,
    display_order,
    section_type,
    requires_subscription,
    requires_test_passed,
    is_active
)
VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'NEW SECTION NAME',
    9,              -- Display after existing sections
    'units',        -- Or 'test', 'recurrent', 'exam'
    true,           -- Requires subscription
    true,           -- Requires test passed
    true
);
```

### Moving a Unit to Different Section

```sql
UPDATE public.course_units
SET section_id = 'new-section-uuid',
    updated_at = timezone('utc'::text, now())
WHERE id = 'unit-uuid';
```

### Reordering Sections

```sql
UPDATE public.course_sections
SET display_order = 5
WHERE id = 'section-uuid';
```

---

## File References

| Purpose | File Path |
|---------|-----------|
| Course Section Model | `Buzz/Models/CourseSection.swift` |
| Course Unit Model | `Buzz/Models/CourseUnit.swift` |
| Training Course Model | `Buzz/Models/TrainingCourse.swift` |
| Academy Service | `Buzz/Services/AcademyService.swift` |
| Course Content View | `Buzz/Views/Academy/CourseContentView.swift` |
| Unit Detail View | `Buzz/Views/Academy/UnitDetailView.swift` |
| Ground School Test View | `Buzz/Views/Academy/GroundSchoolTestView.swift` |
| Test Center Views | `Buzz/Views/Academy/TestCenter/` |
| Section Migration | `supabase/migrations/20251202_add_course_sections.sql` |
| Reorganization Migration | `supabase/migrations/20251202_reorganize_course_sections.sql` |
| Database Schema Reference | `backend_scheme.sql` |

---

## Key Patterns

### 1. Database-Driven UI

The section structure is driven entirely by the database. To change how content appears:
- Modify `course_sections` table (add/remove sections, change order)
- Modify `course_units` table (change `section_id` to move units)
- No code changes needed for content reorganization

### 2. Backward Compatibility

The system maintains backward compatibility through:
- Legacy fallback for courses without sections
- Support for units without `section_id`
- Deprecated `step_number` and `is_mandatory` fields still work

### 3. Type-Based Rendering

The `section_type` field determines how each section renders:
- Add new section types by adding cases to `DynamicSectionView`
- Each type can have completely different UI and behavior

### 4. Lock State Inheritance

Units inherit lock state from their parent section:
- Section's `requiresSubscription` affects all units in that section
- Section's `requiresTestPassed` affects all units in that section
- No per-unit lock configuration needed

