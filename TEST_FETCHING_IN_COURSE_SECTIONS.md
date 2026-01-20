# Test Fetching in Course Sections

This document explains how tests are fetched and organized within course sections in the Buzz Academy system.

## Overview

Tests in the Academy are organized hierarchically:
- **Course Level**: Tests belong to specific courses
- **Section Level**: Tests are grouped within course sections for logical organization
- **Display Level**: Tests are rendered within their respective sections in the UI

## Database Structure

### Test Table Schema
```sql
CREATE TABLE public.course_tests (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,                           -- Links test to course
  section_id uuid,                                   -- Links test to section (NEW)
  test_name text NOT NULL,
  test_type text NOT NULL DEFAULT 'multiple_choice',
  passing_score integer NOT NULL DEFAULT 70,
  required_for_progression boolean DEFAULT true,
  order_index integer NOT NULL DEFAULT 0,
  is_active boolean DEFAULT true,
  needs_proctor boolean DEFAULT false,
  duration integer NOT NULL DEFAULT 60,
  price_of_schedule integer,
  -- ... other fields
  CONSTRAINT course_tests_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id),
  CONSTRAINT course_tests_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.course_sections(id)
);
```

### Section Table Schema
```sql
CREATE TABLE public.course_sections (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,
  name text NOT NULL,
  section_type text DEFAULT 'units',           -- 'units', 'test', 'exam', 'recurrent'
  requires_subscription boolean DEFAULT false,
  requires_test_passed boolean DEFAULT false,
  -- ... other fields
);
```

## Fetching Flow

### Step 1: Fetch All Tests for Course
Tests are fetched at the **course level** first:

```typescript
// API Call
const { data: allTests } = await supabase
  .from('course_tests')
  .select('*')
  .eq('course_id', courseId)
  .eq('is_active', true)
  .order('order_index', { ascending: true });
```

```swift
// Swift Implementation
func fetchCourseTests(courseId: UUID) async throws -> [CourseTest] {
    let response: [CourseTest] = try await supabase
        .from("course_tests")
        .select()
        .eq("course_id", value: courseId.uuidString)
        .eq("is_active", value: true)
        .order("order_index", ascending: true)
        .execute()
        .value

    return response
}
```

### Step 2: Group Tests by Section
After fetching, tests are organized by their `section_id`:

```typescript
// Group tests by section
function groupTestsBySection(tests: CourseTest[]): Record<string, CourseTest[]> {
    const grouped: Record<string, CourseTest[]> = {};

    tests.forEach(test => {
        if (test.sectionId) {
            if (!grouped[test.sectionId]) {
                grouped[test.sectionId] = [];
            }
            grouped[test.sectionId].push(test);
        }
    });

    return grouped;
}

// Usage
const testsBySection = groupTestsBySection(allTests);
```

```swift
// Swift Implementation
var groupedTests: [UUID: [CourseTest]] = [:]

for test in allTests {
    if let sectionId = test.sectionId {
        if groupedTests[sectionId] == nil {
            groupedTests[sectionId] = []
        }
        groupedTests[sectionId]?.append(test)
    }
}
```

### Step 3: Render Tests in Sections
Each section displays its associated tests based on `sectionType`:

```typescript
// Section rendering logic
function renderSection(section: CourseSection, tests: CourseTest[]) {
    switch (section.sectionType) {
        case 'test':
        case 'exam':
            return <TestsSectionView section={section} tests={tests} />;
        case 'units':
            return <UnitsSectionView section={section} />;
        case 'recurrent':
            return <RecurrentTrainingSectionView section={section} />;
        default:
            return null;
    }
}
```

## Section Types and Test Handling

### Test Sections (`sectionType: "test"`)
- Display multiple choice, practical, or written tests
- Tests appear in a list within the section
- Support both proctored and self-administered tests

### Exam Sections (`sectionType: "exam"`)
- Display formal examinations (Flight Review, ROC-A)
- Use `examType` field to determine specific exam
- Navigate to exam scheduling/test center flow

## Access Control

Tests inherit section-level access controls:

```typescript
function canAccessTest(test: CourseTest, section: CourseSection, userStatus: UserStatus): boolean {
    // Check section requirements
    if (section.requiresSubscription && !userStatus.hasSubscription) {
        return false;
    }

    if (section.requiresTestPassed && !userStatus.hasPassedPrerequisiteTest) {
        return false;
    }

    // Check test-specific requirements
    // (additional logic for test prerequisites)

    return true;
}
```

## UI Implementation

### Tests Section View
```typescript
interface TestsSectionViewProps {
    section: CourseSection;
    tests: CourseTest[];
    course: TrainingCourse;
    hasPassedTest: boolean;
    passedTestIds: string[];
}

function TestsSectionView({ section, tests, course, hasPassedTest, passedTestIds }: TestsSectionViewProps) {
    return (
        <div className="section-container">
            <h3 className="section-title">{section.name}</h3>

            <div className="tests-list">
                {tests
                    .sort((a, b) => a.orderIndex - b.orderIndex)
                    .map(test => (
                        <TestRow
                            key={test.id}
                            test={test}
                            course={course}
                            isLocked={section.requiresTestPassed && !hasPassedTest}
                            isPassed={passedTestIds.includes(test.id)}
                            sectionDescription={section.description}
                        />
                    ))}
            </div>
        </div>
    );
}
```

### Test Row Component
```typescript
function TestRow({ test, course, isLocked, isPassed, sectionDescription }) {
    const getTestIcon = (testType: string) => {
        switch (testType) {
            case 'multiple_choice': return 'doc.text.fill';
            case 'practical': return 'airplane';
            case 'oral': return 'antenna.radiowaves.left.and.right';
            default: return 'checkmark.circle.fill';
        }
    };

    if (isLocked) {
        return (
            <div className="test-row locked">
                <div className="test-icon locked">
                    <span>🔒</span>
                </div>
                <div className="test-content">
                    <h4>{test.testName}</h4>
                    <p>{test.testDescription || sectionDescription}</p>
                    <span className="lock-reason">Complete prerequisite test to unlock</span>
                </div>
            </div>
        );
    }

    return (
        <Link to={test.needsProctor ? `/proctor-test/${test.id}` : `/test/${test.id}`}>
            <div className="test-row">
                <div className="test-icon">
                    <span>{getTestIcon(test.testType)}</span>
                </div>
                <div className="test-content">
                    <h4>{test.testName}</h4>
                    <p>{test.testDescription || sectionDescription}</p>
                    {test.needsProctor && (
                        <span className="proctor-badge">Requires Proctor</span>
                    )}
                    {isPassed && (
                        <span className="passed-badge">✓ Passed</span>
                    )}
                </div>
                <div className="chevron">→</div>
            </div>
        </Link>
    );
}
```

## Legacy Support

For courses without database sections, tests are handled differently:

```typescript
// Fallback for courses without sections
function createLegacyTestSection(tests: CourseTest[]): CourseSection {
    return {
        id: 'legacy-test-section',
        name: 'GROUND SCHOOL TEST',
        sectionType: 'test',
        requiresSubscription: false,
        requiresTestPassed: false,
        // ... other fields
    };
}

// Check if course has sections defined
if (sections.length === 0 && tests.length > 0) {
    // Use legacy fallback
    const legacySection = createLegacyTestSection(tests);
    renderSection(legacySection, tests);
}
```

## API Endpoints

### Fetch Course Tests
```typescript
// GET /course_tests?course_id=eq.{courseId}&is_active=eq.true&order=order_index.asc
// Returns: CourseTest[]
```

### Fetch Test Questions
```typescript
// GET /test_questions?test_id=eq.{testId}&order=question_number.asc
// Returns: TestQuestion[]
```

### Check Test Status
```typescript
// GET /test_results?pilot_id=eq.{pilotId}&test_id=eq.{testId}&passed=eq.true
// Returns: boolean (whether test is passed)
```

## Performance Considerations

1. **Batch Fetching**: Fetch all tests for a course in one query
2. **Lazy Loading**: Load test questions only when needed
3. **Caching**: Cache test metadata and results
4. **Pagination**: For courses with many tests

## Error Handling

```typescript
async function loadCourseTests(courseId: string) {
    try {
        const tests = await fetchCourseTests(courseId);
        return groupTestsBySection(tests);
    } catch (error) {
        console.error('Error loading course tests:', error);
        // Return empty object or show error UI
        return {};
    }
}
```

## Testing Strategy

1. **Unit Tests**: Test grouping logic and access control
2. **Integration Tests**: Test full fetching and rendering flow
3. **E2E Tests**: Test user interaction with tests in sections

## Migration Notes

- **Before**: Tests were organized by `step_number` (legacy)
- **After**: Tests linked to sections via `section_id`
- **Backward Compatibility**: Legacy courses still supported via fallback logic

This approach provides flexible test organization while maintaining performance and backward compatibility.