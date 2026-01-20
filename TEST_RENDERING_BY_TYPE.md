# Test Rendering by Type and Conditions

This document explains how different test types are rendered in the Buzz Academy system, including the various conditions, user states, and navigation flows for each test type.

## Test Type Overview

The Academy supports several test types, each with different rendering logic:

- **multiple_choice**: Self-administered multiple choice questions
- **practical**: Hands-on flight demonstrations (requires upload)
- **oral**: Verbal examination with proctor (requires upload)
- **written**: Written examination (requires upload)

## Test Rendering Decision Tree

### Primary Decision: Proctor Required

```swift
if test.needsProctor {
    // Navigate to ProctorTestIntroView (scheduling)
    NavigationLink(destination: ProctorTestIntroView(...)) {
        TestCardContent(...)
    }
} else {
    // Navigate to TestIntroView (immediate start)
    NavigationLink(destination: TestIntroView(...)) {
        TestCardContent(...)
    }
}
```

### Secondary Decision: Test Type and Format

```swift
switch test.testType {
case "multiple_choice":
    if test.needsProctor {
        // ProctoredMultipleChoiceTestView with proctor supervision
        ProctoredMultipleChoiceTestView(...)
    } else {
        // MultipleChoiceTestView self-administered
        MultipleChoiceTestView(...)
    }

case "practical", "oral", "written":
    // Always requires upload, never self-administered
    // Navigate to ExamIntroView for scheduling/upload
    ExamIntroView(examType: ...)
}
```

## Test Types and Rendering Logic

### 1. Multiple Choice Tests (`multiple_choice`)

#### Self-Administered (Non-Proctored)
**Conditions**: `test.needsProctor == false`

**Navigation Flow**:
```
TestRow → TestIntroView → MultipleChoiceTestView → Test Results
```

**Key Features**:
- Immediate test start after intro
- 60-minute timer with auto-submit
- Question navigation with progress tracking
- Real-time answer saving
- Score calculation and pass/fail determination

**UI Components**:

#### GroundSchoolTestIntroView
A comprehensive introduction screen that prepares users for taking the Ground School Test. This view serves as an educational gateway before the actual test begins.

**Key Features**:
- **Milestone Celebration**: Shows congratulatory message for reaching test eligibility
- **Test Overview Card**: Displays critical test information in a structured card format
- **Test Statistics**: Shows question count (70), time limit (60 minutes), passing score (80%)
- **Knowledge Area Breakdown**: Lists FAA test areas with percentage weights:
  - Regulations (30%)
  - Airspace (15%)
  - Weather (10%)
  - Loading & Performance (5%)
  - Operations (40%)
- **Test Rules Section**: Clear instructions about test-taking behavior
- **Call-to-Action**: Prominent "Start Test" button that triggers navigation

**Data Flow**:
- Receives `course: TrainingCourse` parameter for context
- Uses `onStartTest: () -> Void` closure to signal parent view to navigate to test
- No state management - purely presentational with callback-based navigation

**Design Elements**:
- Uses SF Symbols: `star.circle.fill` for celebration icon
- Color scheme: Yellow stars, blue accent colors for information
- Card-based layout with rounded corners and subtle shadows
- Responsive padding and spacing for different screen sizes

#### Navigation Flow Implementation
```swift
// In parent view (CourseContentView)
NavigationLink(
    destination: GroundSchoolTestIntroView(
        course: course,
        onStartTest: { navigateToTest = true }
    ),
    isActive: $navigateToTest
) {
    EmptyView()
}
.hidden()

// GroundSchoolTestIntroView button action
Button(action: onStartTest) {
    // Styled start button
}
```

#### MultipleChoiceTestView Integration
After intro screen, navigates to the actual test interface:

```swift
// Full initialization with all required parameters
MultipleChoiceTestView(
    testId: test.id,                           // UUID of the test to load
    course: course,                            // Course context for branding
    pilotId: pilotId,                          // User identification for results
    testName: test.testName,                    // Display name for navigation
    passingScore: test.passingScore,            // Passing threshold (e.g., 70)
    durationMinutes: test.duration ?? 60        // Test time limit in minutes
)
```

**Parameter Details**:
- `testId`: Links to database test record and loads associated questions
- `course`: Provides context for result storage and UI theming
- `pilotId`: Associates results with specific user account
- `testName`: Navigation bar title and result display
- `passingScore`: Percentage threshold for pass/fail determination
- `durationMinutes`: Timer initialization (default 60 minutes)

#### Proctored Multiple Choice
**Conditions**: `test.needsProctor == true`

**Navigation Flow**:
```
TestRow → ProctorTestSchedulingView → Payment → ProctoredMultipleChoiceTestView → Test Results
```

**Important Note**: Unlike self-administered tests, proctored multiple choice tests skip the intro screen and go directly to scheduling, as the scheduling process itself serves as the introduction and preparation phase.

#### ProctorTestSchedulingView (ProctorTestIntroView Functionality)
This view combines introduction, scheduling, and payment functionality for proctored exams. It serves as both the introduction screen and the scheduling interface.

**Key Components**:

##### Exam Summary Card (Introduction Section)
```swift
ExamSummaryTestCard(test: test, course: course)
```
- Displays test name, description, and course context
- Shows test type icon and key information
- Acts as the "introduction" to what the exam entails

##### Date Selection Section
- **Minimum Date**: Tomorrow (prevents same-day scheduling)
- **Maximum Date**: 3 months in the future (reasonable scheduling window)
- **Date Picker**: Native iOS date picker with restrictions
- **Available Time Slots**: Generated programmatically (9 AM - 5 PM, 30-minute intervals)

##### Location Selection
- **Online**: Virtual proctored exam via Zoom
- **In-Person**: Physical location with on-site proctor
- **Address Field**: Required for in-person exams, hidden for online

##### Payment Integration
- **Stripe Payment Sheet**: Integrated payment processing
- **Dynamic Pricing**: Fetches current price from Stripe products
- **Payment Intent Creation**: Server-side payment intent generation
- **Success Handling**: Creates exam appointment record on successful payment

**State Management**:
```swift
@State private var selectedDate = Date()
@State private var selectedTime: Date?
@State private var locationType: ExamLocationType = .inPerson
@State private var locationAddress = ""
@State private var paymentSheet: PaymentSheet?
@State private var showPaymentSuccess = false
```

**Business Logic**:
```swift
// Scheduling validation
private var canProceed: Bool {
    guard selectedTime != nil else { return false }
    if locationType == .inPerson {
        return !locationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    return true
}

// Date/time combination for appointment
private var scheduledDateTime: Date? {
    guard let time = selectedTime else { return nil }
    // Combines selected date with selected time
    // Returns nil if either is missing
}
```

**Zoom Integration for Online Exams**:
- Automatically creates Zoom meeting upon successful payment
- Generates join URL and meeting details
- Stores meeting information in appointment record
- Sends confirmation email with meeting link

**Appointment Creation**:
Upon successful payment, creates `exam_appointments` record with:
- Pilot ID, exam type, scheduled date/time
- Location details (type and address)
- Payment information (intent ID, amount)
- Zoom meeting details (if online)
- Proctor assignment (if applicable)

### 2. Practical Tests (`practical`)

**Conditions**: Always requires proctor and upload

**Navigation Flow**:
```
TestRow → ExamIntroView → Scheduling → Flight Demo → Upload Results → Admin Review → Final Result
```

**Key Features**:
- No self-administered component - requires physical flight demonstration
- Professional pilot evaluation during actual flight operations
- Results consist of flight logs, videos, and evaluator assessments
- Manual review by certified flight instructors or examiners
- Status tracking through multiple stages: scheduled → completed → under review → approved/rejected

#### ExamIntroView Deep Dive
The central hub for all formal examinations, dynamically adapting its interface based on exam type and user progress.

**Core Components**:

##### Header Section (Visual Branding)
```swift
// Dynamic header based on exam type
ZStack {
    LinearGradient(colors: [examType.color.opacity(0.6), examType.color], ...)
    VStack(spacing: 12) {
        Image(systemName: config.icon)
            .font(.system(size: 60))
        // Exam type specific messaging
    }
}
```
- **Color Coding**: Each exam type has distinct color scheme (Flight Review: blue, ROC-A: different shade)
- **Icon Display**: Uses `examTypeConfig.icon` for visual recognition
- **Gradient Background**: Creates professional, branded appearance

##### Prerequisites Validation
```swift
// Real-time prerequisite checking
private var prerequisitesStatus: ExamPrerequisitesStatus?

// Automatically loads on view appear
.task {
    do {
        prerequisitesStatus = try await examService.checkPrerequisites(pilotId)
    } catch {
        // Handle prerequisite check failures
    }
}
```
- **Ground School Test**: Must be passed before any formal exams
- **Unit 4 Completion**: Required for practical flight evaluations
- **Real-time Status**: Updates automatically when view loads

##### Dynamic Content Sections
The view adapts its content based on exam type and user status:

###### For Exams Requiring Upload (`practical`, `oral`, `written`)
```swift
if requiresUpload {
    // Show upload interface
    VStack {
        UploadStatusIndicator(status: uploadStatus)
        FileUploadSection()
        StatusTimelineView()
    }
}
```

###### For Exams Requiring Scheduling (`ground_school_test` if proctored)
```swift
else {
    // Show scheduling interface
    VStack {
        ExamSchedulingCard()
        PaymentInformationCard()
        ProctorInformationCard()
    }
}
```

##### Upload Status Tracking
```swift
enum TestUploadStatus {
    case notSubmitted    // Initial state
    case pending         // Submitted, under review
    case approved        // Passed review
    case rejected        // Failed review
}
```
- **Visual Indicators**: Color-coded status badges
- **Progress Timeline**: Shows review progress
- **Action Buttons**: Upload, re-upload, or view results

##### Payment Integration
```swift
// Dynamic pricing based on exam type
@State private var priceInfo: ExamPriceResponse?

.task {
    do {
        priceInfo = try await examService.fetchExamPrice(examType: examType)
    } catch {
        priceError = error.localizedDescription
    }
}
```
- **Stripe Product Integration**: Each exam type links to specific Stripe product
- **Real-time Pricing**: Fetches current prices from Stripe API
- **Payment Sheet**: Native Stripe payment interface

**State Management**:
- **Loading States**: Separate loaders for price, prerequisites, test results
- **Error Handling**: Specific error messages for different failure points
- **Navigation Control**: Conditional button enabling based on prerequisites and status

**Business Logic Methods**:
- `requiresUpload`: Determines if exam needs file submission vs scheduling
- `isProctored`: Checks if exam requires live proctor supervision
- `hasPassed`: Computed property based on test results
- `uploadStatus`: Maps database status to UI-friendly enum

### 3. Oral Tests (`oral`)

**Conditions**: Always requires proctor and upload

**Navigation Flow**:
```
TestRow → ExamIntroView → Scheduling → Proctor Info → Test Session → Upload Results
```

**Key Features**:
- Video/audio recording capability
- Proctor-mediated examination
- Results uploaded post-examination
- Manual grading and verification

### 4. Written Tests (`written`)

**Conditions**: Always requires proctor and upload

**Navigation Flow**:
```
TestRow → ExamIntroView → Scheduling → Proctor Info → Test Session → Scan/Upload Results
```

**Key Features**:
- Physical written examination
- Document scanning for results
- Proctor supervision during exam
- Manual grading process

## Condition-Based Rendering

### Lock Status Determination

```swift
var isLocked: Bool {
    // Section-level locks
    let sectionRequiresTest = section.requiresTestPassed && !hasPassedPrerequisite
    let sectionRequiresSubscription = section.requiresSubscription && !hasSubscription

    // Test-specific locks (if any)
    // ...

    return sectionRequiresTest || sectionRequiresSubscription
}

var lockReason: String {
    if section.requiresTestPassed && !hasPassedPrerequisite {
        return "Complete prerequisite test first"
    }
    if section.requiresSubscription && !hasSubscription {
        return "Subscribe to access this test"
    }
    return ""
}
```

### User State Conditions

#### 1. Anonymous User (Not Logged In)
```swift
if authService.currentUser == nil {
    // Show test card without navigation
    TestCardContent(
        test: test,
        isLocked: false,
        lockReason: "",
        isPassed: false
    )
}
```

#### 2. Authenticated User - Test Available
```swift
if !isLocked && authService.currentUser != nil {
    if test.needsProctor {
        // Proctored test flow
        NavigationLink(destination: ProctorTestIntroView(
            test: test,
            pilotId: currentUser.id,
            isEligible: true,
            hasPassed: isPassed
        )) {
            TestCardContent(...)
        }
    } else {
        // Self-administered test flow
        NavigationLink(destination: TestIntroView(
            test: test,
            pilotId: currentUser.id,
            hasPassed: isPassed
        )) {
            TestCardContent(...)
        }
    }
}
```

#### 3. Authenticated User - Test Locked
```swift
if isLocked {
    // Show disabled card with lock reason
    TestCardContent(
        test: test,
        isLocked: true,
        lockReason: lockReason,
        isPassed: false
    )
}
```

#### 4. Test Already Passed
```swift
if isPassed {
    // Show passed indicator
    TestCardContent(
        test: test,
        isLocked: false,
        lockReason: "",
        isPassed: true  // Shows green checkmark
    )
}
```

## UI Components by Test Type

### TestCardContent Component

The unified card component that displays test information with dynamic styling and interaction based on test state and user permissions.

**Component Architecture**:

```swift
struct TestCardContent: View {
    let test: CourseTest
    let sectionDescription: String?
    let isLocked: Bool
    let lockReason: String
    let isPassed: Bool

    // MARK: - Visual Styling Logic

    var testIcon: String {
        switch test.testType {
        case "multiple_choice":
            return "doc.text.fill"           // Document icon for text-based tests
        case "practical":
            return "airplane"                // Airplane for flight demonstrations
        case "oral":
            return "antenna.radiowaves.left.and.right"  // Radio waves for verbal communication
        case "written":
            return "pencil.and.outline"      // Pencil for written examinations
        default:
            return "checkmark.circle.fill"   // Generic completion icon
        }
    }

    var testColor: Color {
        if isLocked {
            return .gray                         // Disabled appearance
        } else if isPassed {
            return .green                        // Success state
        } else {
            return .blue                         // Active/default state
        }
    }

    var backgroundColor: Color {
        if isLocked {
            return Color(.systemGray5)           // Muted background
        } else {
            return Color(.systemGray6)           // Standard card background
        }
    }

    var opacity: Double {
        return isLocked ? 0.7 : 1.0             // Visual disabled state
    }

    // MARK: - Layout Structure

    var body: some View {
        HStack(spacing: 16) {
            // Icon Section
            iconSection

            // Content Section
            contentSection

            // Action Section
            actionSection
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .opacity(opacity)
    }

    // MARK: - Subcomponents

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(testColor.opacity(0.2))
                .frame(width: 50, height: 50)

            if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .font(.headline)
            } else {
                Image(systemName: testIcon)
                    .foregroundColor(testColor)
                    .font(.headline)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title with status indicators
            titleSection

            // Description text
            descriptionSection

            // Status indicators
            statusSection
        }
    }

    private var titleSection: some View {
        HStack {
            Text(test.testName)
                .font(.headline)
                .foregroundColor(isLocked ? .secondary : .primary)

            if isPassed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }

            if isLocked {
                Text("🔒")
                    .font(.caption)
            }
        }
    }

    private var descriptionSection: some View {
        Group {
            if let description = test.testDescription ?? sectionDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var statusSection: some View {
        Group {
            if isLocked && !lockReason.isEmpty {
                statusText(lockReason, color: .blue)
            } else if test.needsProctor {
                statusText("Requires scheduling", color: .blue, icon: "calendar.badge.clock")
            } else if !isLocked {
                statusText("60 min", color: .secondary, icon: "clock")
            }
        }
    }

    private func statusText(_ text: String, color: Color, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
            }
            Text(text)
                .font(.caption)
                .foregroundColor(color)
                .fontWeight(.semibold)
        }
    }

    private var actionSection: some View {
        Group {
            if isLocked {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}
```

**Detailed Component Breakdown**:

#### Icon Section
- **Circular Background**: Semi-transparent color fill that adapts to test state
- **Dynamic Icon**: Changes based on test type or lock state
- **Size**: Fixed 50x50pt circle for consistency
- **Lock Override**: Shows lock icon when test is unavailable

#### Content Section (Main Information)
- **Title**: Test name with status indicators (checkmark for passed, lock for restricted)
- **Description**: Test description or section description, limited to 2 lines
- **Status Indicators**: Contextual information based on test state

#### Status Logic
```swift
// Priority-based status display
if isLocked && !lockReason.isEmpty {
    // Show lock reason (highest priority)
    "Complete prerequisite test first"
} else if test.needsProctor {
    // Show scheduling requirement
    "Requires scheduling"
} else if !isLocked {
    // Show time estimate for available tests
    "60 min"
}
```

#### Action Section
- **Chevron**: Right arrow indicating tappable state
- **Lock Icon**: Visual indicator for restricted access
- **Color Coding**: Gray for locked, secondary for active

### Test Icon Mapping Reference

| Test Type | SF Symbol | Contextual Meaning | Use Case |
|-----------|-----------|-------------------|----------|
| `multiple_choice` | `doc.text.fill` | Document with text content | Text-based question exams |
| `practical` | `airplane` | Flight operations | Hands-on flight demonstrations |
| `oral` | `antenna.radiowaves.left.and.right` | Communication signals | Verbal examinations |
| `written` | `pencil.and.outline` | Writing instrument | Physical written tests |
| **Locked State** | `lock.fill` | Access restriction | Any test when unavailable |
| **Passed State** | `checkmark.circle.fill` | Completion achievement | Successfully completed tests |

### State-Based Visual Variations

#### Available Test (Default State)
- **Colors**: Blue theme with full opacity
- **Icons**: Test-type specific SF Symbols
- **Interaction**: Tappable with navigation chevron
- **Background**: Standard system gray

#### Passed Test
- **Colors**: Green accent for success indication
- **Icons**: Checkmark overlay on test-type icon
- **Status**: "✓ Passed" badge
- **Styling**: Maintained full interactivity

#### Locked Test
- **Colors**: Gray theme for disabled appearance
- **Icons**: Lock symbol replacing test-type icon
- **Opacity**: Reduced to 70% for visual hierarchy
- **Background**: Muted system gray
- **Interaction**: Non-tappable, shows lock reason

This component ensures consistent visual language across all test types while clearly communicating availability, progress, and required actions to users.

## Special Views by Test Type

### Multiple Choice Tests

#### GroundSchoolTestIntroView
- Shows test overview (70 questions, 60 min, 80% passing)
- Displays test areas breakdown
- Rules and instructions
- Start test button

#### MultipleChoiceTestView (Core Test Engine)
The primary test-taking interface that handles the complete multiple choice testing experience.

**Key Architectural Components**:

##### Question Management System
```swift
@State private var questions: [TestQuestion] = []
@State private var currentQuestionIndex = 0

// Dynamic question access
var currentQuestion: TestQuestion {
    questions[currentQuestionIndex]
}
```
- **Question Loading**: Fetches questions via `AcademyService.fetchTestQuestions()`
- **Randomization Support**: Handles problem set randomization for fair testing
- **Index-based Navigation**: Maintains current position in question array

##### Answer Tracking System
```swift
@State private var selectedAnswers: [UUID: Int] = [:]

// Answer storage by question ID
private func selectAnswer(questionId: UUID, answerIndex: Int) {
    selectedAnswers[questionId] = answerIndex
    // Optional: Auto-advance to next question
}

// Progress calculation
var progress: Double {
    guard !questions.isEmpty else { return 0 }
    return Double(selectedAnswers.count) / Double(questions.count)
}
```
- **Persistent Storage**: Answers survive app backgrounding/navigation
- **Real-time Progress**: Visual progress bar updates instantly
- **Answer Validation**: Prevents invalid answer indices

##### Timer Management System
```swift
@State private var timeRemaining: TimeInterval
@State private var timer: Timer?

// Initialization
init(..., durationMinutes: Int, ...) {
    self._timeRemaining = State(initialValue: TimeInterval(durationMinutes * 60))
}

// Timer lifecycle
.task {
    startTimer()
}

private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            autoSubmitTest()
        }
    }
}
```
- **Countdown Display**: `MM:SS` format in navigation bar
- **Auto-submission**: Triggers when time reaches zero
- **Background Handling**: Timer pauses when app backgrounds
- **Warning States**: Visual indicators at 5-minute and 1-minute marks

##### Navigation and UI Controls
```swift
// Question navigator
@State private var showQuestionNavigator = false

// Chart/image viewer
@State private var showChartViewer = false
@State private var selectedChartURL: URL?

// Exit confirmation
@State private var showExitAlert = false
```
- **Question Navigator**: Grid view of all questions with answer status
- **Chart Viewer**: Modal for viewing question images/diagrams
- **Exit Protection**: Prevents accidental test abandonment

##### Submission and Results Flow
```swift
@State private var showResults = false
@State private var testScore = 0
@State private var passed = false

private func submitTest() async {
    // Calculate score
    let correctAnswers = calculateCorrectAnswers()
    testScore = Int((Double(correctAnswers) / Double(questions.count)) * 100)

    // Determine pass/fail
    passed = testScore >= passingScore

    // Save to database
    await saveTestResult()

    // Show results screen
    showResults = true
}
```
- **Score Calculation**: Compares selected answers with correct answers
- **Database Persistence**: Saves `test_results` record with full answer data
- **Results Screen**: Detailed breakdown with explanations

**UI Layout Structure**:
```
NavigationView
├── NavigationBar (Timer + Progress + Navigator Button)
├── QuestionContent
│   ├── QuestionText
│   ├── AnswerOptions (A, B, C, D)
│   └── ImageViewer (if question has images)
├── NavigationControls
│   ├── Previous/Next Buttons
│   └── SubmitButton (when all answered)
└── ModalSheets
    ├── QuestionNavigator
    └── ChartViewer
```

#### ProctoredMultipleChoiceTestView (Supervised Testing)
Extends `MultipleChoiceTestView` with proctor oversight capabilities.

**Key Differences from Standard MCQ**:

##### Proctor Identity Tracking
```swift
let proctorName: String  // Passed during initialization

// Included in test result submission
private func saveTestResult() async {
    let result = TestResult(
        // ... standard fields
        proctorName: proctorName,  // Additional field
        // ... other fields
    )
    await database.save(result)
}
```

##### Enhanced Security Features
- **Screen Monitoring**: Proctor can observe test-taking process
- **Identity Verification**: Proctor confirms test-taker identity
- **Incident Reporting**: Proctor can flag suspicious behavior
- **Result Verification**: Proctor reviews and approves final submission

##### Modified Submission Flow
```swift
private func submitTest() async {
    // Standard scoring calculation
    let score = calculateScore()

    // Proctor verification step
    let proctorApproved = await requestProctorApproval()

    if proctorApproved {
        // Save with proctor verification
        await saveProctoredResult(score: score, proctorName: proctorName)
    } else {
        // Handle proctor rejection
        show ProctorRejectionAlert()
    }
}
```

##### Proctor Communication Interface
- **Real-time Chat**: Text communication during test
- **Issue Reporting**: Proctor can pause test for technical issues
- **Time Extensions**: Proctor can grant additional time if needed

**Use Cases**:
- **FAA Knowledge Tests**: Official FAA examinations
- **Recurrent Training**: Required periodic testing
- **Certification Exams**: Industry-specific certifications

Both variants maintain the same core testing engine but adapt security and verification processes based on supervision requirements.

### Formal Exams (Practical/Oral/Written)

#### ExamIntroView
- Exam overview and pricing
- Prerequisites checking
- Scheduling options (online/in-person)
- Upload section for completed exams
- Status tracking (pending/approved/rejected)

#### ProctorTestSchedulingView
- Date/time selection
- Location selection (online/in-person)
- Payment processing via Stripe
- Zoom meeting creation for online exams

## Test Status Indicators

### Lock States
```swift
if isLocked {
    // Lock icon and gray styling
    Image(systemName: "lock.fill")
        .foregroundColor(.gray)

    // Lock reason text
    Text(lockReason)
        .foregroundColor(.blue)
        .fontWeight(.semibold)
}
```

### Completion States
```swift
if isPassed {
    // Green checkmark
    Image(systemName: "checkmark.circle.fill")
        .foregroundColor(.green)

    Text("Passed")
        .foregroundColor(.green)
        .fontWeight(.semibold)
}
```

### Proctor Required Indicator
```swift
if test.needsProctor {
    HStack(spacing: 4) {
        Image(systemName: "calendar.badge.clock")
            .foregroundColor(.blue)
        Text("Requires scheduling")
            .foregroundColor(.blue)
            .fontWeight(.semibold)
    }
}
```

## Navigation Logic

### TestRow Navigation Decision Tree

The routing system that determines where users are taken when they tap on a test card. This logic ensures users get the appropriate interface based on test type, availability, and user authentication status.

#### Primary Decision Flow

```swift
func getNavigationDestination(test: CourseTest, isLocked: Bool, currentUser: User?) -> some View {
    // Step 1: Check if test is accessible
    if isLocked {
        // Test is blocked by prerequisites or subscription
        return TestCardContent(
            test: test,
            isLocked: true,
            lockReason: determineLockReason(test),
            isPassed: false
        )
    }

    // Step 2: Verify user authentication
    guard let user = currentUser else {
        // Anonymous users see card but cannot interact
        return TestCardContent(
            test: test,
            isLocked: false,
            lockReason: "",
            isPassed: false
        )
    }

    // Step 3: Route based on test type and requirements
    return getTestSpecificDestination(test: test, user: user)
}

private func getTestSpecificDestination(test: CourseTest, user: User) -> some View {
    switch test.testType {
    case "multiple_choice":
        return getMultipleChoiceDestination(test: test, user: user)

    case "practical", "oral", "written":
        return getFormalExamDestination(test: test, user: user)

    default:
        // Unknown test type - show card without navigation
        return TestCardContent(
            test: test,
            isLocked: false,
            lockReason: "",
            isPassed: checkIfPassed(test: test, user: user)
        )
    }
}
```

#### Multiple Choice Test Routing

```swift
private func getMultipleChoiceDestination(test: CourseTest, user: User) -> some View {
    let isPassed = checkIfPassed(test: test, user: user)

    if test.needsProctor {
        // Proctored MCQ: Direct to scheduling (no intro needed)
        return NavigationLink(destination:
            ProctorTestSchedulingView(
                test: test,
                course: getCourseForTest(test),
                pilotId: user.id
            )
        ) {
            TestCardContent(
                test: test,
                isLocked: false,
                lockReason: "",
                isPassed: isPassed
            )
        }
    } else {
        // Self-administered MCQ: Go to intro screen first
        return NavigationLink(destination:
            GroundSchoolTestIntroView(
                course: getCourseForTest(test),
                onStartTest: {
                    // Parent view handles navigation to actual test
                    navigateToTest(testId: test.id)
                }
            )
        ) {
            TestCardContent(
                test: test,
                isLocked: false,
                lockReason: "",
                isPassed: isPassed
            )
        }
    }
}
```

**Key Differences**:
- **Proctored MCQ**: Skips intro, goes directly to scheduling because scheduling serves as preparation
- **Self-administered MCQ**: Shows intro screen first to explain test format and rules

#### Formal Exam Routing (Practical/Oral/Written)

```swift
private func getFormalExamDestination(test: CourseTest, user: User) -> some View {
    let examType = mapTestToExamType(test)
    let isPassed = checkIfPassed(test: test, user: user)

    return NavigationLink(destination:
        ExamIntroView(examType: examType)
    ) {
        TestCardContent(
            test: test,
            isLocked: false,
            lockReason: "",
            isPassed: isPassed
        )
    }
}

private func mapTestToExamType(_ test: CourseTest) -> ExamType {
    // Map database test types to enum values
    switch test.testType {
    case "practical":
        return .flightReview  // Practical tests are flight reviews
    case "oral":
        return .rocA         // Oral exams are ROC-A
    case "written":
        return .rocA         // Written exams are also ROC-A
    default:
        return .groundSchoolTest  // Fallback
    }
}
```

**Formal Exam Flow**:
1. **Single Entry Point**: All formal exams go through `ExamIntroView`
2. **Dynamic Content**: View adapts based on exam type and user status
3. **Unified Experience**: Consistent interface for scheduling, uploading, and status tracking

### Helper Functions

#### Lock Reason Determination
```swift
private func determineLockReason(test: CourseTest) -> String {
    // Check section-level restrictions first
    if let section = getSectionForTest(test) {
        if section.requiresSubscription && !userHasSubscription() {
            return "Subscribe to Buzz Academy Pass"
        }

        if section.requiresTestPassed && !hasPassedPrerequisiteTest() {
            return "Complete Ground School Test to unlock"
        }
    }

    // Check test-specific prerequisites
    if let requiredTests = test.prerequisiteTests, !requiredTests.isEmpty {
        let passedRequiredTests = requiredTests.filter { testId in
            checkIfPassed(testId: testId, user: currentUser)
        }
        if passedRequiredTests.count < requiredTests.count {
            return "Complete prerequisite test(s)"
        }
    }

    // Check unit completion requirements
    if let requiredUnits = test.requiredUnits, !requiredUnits.isEmpty {
        let completedRequiredUnits = requiredUnits.filter { unitNumber in
            checkIfUnitCompleted(unitNumber: unitNumber, user: currentUser)
        }
        if completedRequiredUnits.count < requiredUnits.count {
            let remaining = requiredUnits.count - completedRequiredUnits.count
            return "Complete \(remaining) more unit(s)"
        }
    }

    return "Prerequisites not met"
}
```

#### Pass Status Checking
```swift
private func checkIfPassed(test: CourseTest, user: User) -> Bool {
    // Query test_results table for passed status
    let passedResults = supabase
        .from("test_results")
        .select("passed")
        .eq("pilot_id", value: user.id.uuidString)
        .eq("test_id", value: test.id.uuidString)
        .eq("passed", value: true)

    return passedResults.count > 0
}
```

### Navigation State Management

#### Parent View Coordination
```swift
// In CourseContentView or similar parent
@State private var navigateToTest = false
@State private var selectedTestId: UUID?

// Background navigation link for test launching
var testNavigationLink: some View {
    NavigationLink(
        destination: Group {
            if let testId = selectedTestId,
               let test = findTestById(testId),
               let user = authService.currentUser {
                MultipleChoiceTestView(
                    testId: testId,
                    course: course,
                    pilotId: user.id,
                    testName: test.testName,
                    passingScore: test.passingScore,
                    durationMinutes: test.duration ?? 60
                )
            }
        },
        isActive: $navigateToTest
    ) {
        EmptyView()
    }
    .hidden()
}

// Trigger navigation from intro view
func navigateToTest(testId: UUID) {
    selectedTestId = testId
    navigateToTest = true
}
```

This navigation system ensures users are always taken to the most appropriate interface based on their current state, test requirements, and authentication status, while maintaining a consistent and intuitive user experience across all test types.

## Error States and Edge Cases

### Network and Data Loading Errors

#### Question Loading Failures
```swift
@State private var questions: [TestQuestion] = []
@State private var isLoading = true
@State private var errorMessage: String?

.task {
    await loadTestQuestions()
}

private func loadTestQuestions() async {
    do {
        questions = try await academyService.fetchTestQuestions(testId: testId)
        isLoading = false

        // Validate loaded data
        if questions.isEmpty {
            throw TestError.noQuestionsConfigured
        }

        // Check for question integrity
        for question in questions {
            if question.options.isEmpty {
                throw TestError.malformedQuestion(questionId: question.id)
            }
            if question.correctAnswerIndex >= question.options.count {
                throw TestError.invalidCorrectAnswer(questionId: question.id)
            }
        }

    } catch TestError.noQuestionsConfigured {
        errorMessage = "This test has not been properly configured. Please contact support."
        isLoading = false
    } catch TestError.malformedQuestion(let questionId) {
        errorMessage = "Test question \(questionId) is improperly configured."
        isLoading = false
    } catch TestError.invalidCorrectAnswer(let questionId) {
        errorMessage = "Test question \(questionId) has an invalid answer configuration."
        isLoading = false
    } catch let error as URLError where error.code == .notConnectedToInternet {
        errorMessage = "No internet connection. Please check your network and try again."
        isLoading = false
    } catch {
        errorMessage = "Failed to load test questions: \(error.localizedDescription)"
        isLoading = false
    }
}
```

**Error Recovery Strategies**:
- **Retry Logic**: Automatic retry for transient network errors
- **Graceful Degradation**: Show cached questions if available
- **User Feedback**: Clear error messages with actionable steps
- **Fallback UI**: Basic test interface when questions fail to load

#### Database Connection Issues
```swift
catch let error as PostgrestError {
    switch error.code {
    case "PGRST116":  // Row Level Security violation
        errorMessage = "You don't have permission to access this test."
    case "42P01":     // Table doesn't exist
        errorMessage = "Test system is currently unavailable. Please try again later."
    default:
        errorMessage = "Database error occurred. Please try again."
    }
}
```

### Test Configuration Validation

#### Empty or Invalid Tests
```swift
// Pre-test validation
private func validateTestConfiguration() throws {
    guard !test.testName.isEmpty else {
        throw TestConfigurationError.missingTestName
    }

    guard test.passingScore >= 0 && test.passingScore <= 100 else {
        throw TestConfigurationError.invalidPassingScore
    }

    guard test.duration ?? 0 > 0 else {
        throw TestConfigurationError.invalidDuration
    }

    // Validate question count is reasonable
    guard questions.count >= 1 else {
        throw TestConfigurationError.insufficientQuestions
    }
}
```

#### Question Integrity Checks
```swift
private func validateQuestionIntegrity() -> [ValidationError] {
    var errors: [ValidationError] = []

    for (index, question) in questions.enumerated() {
        // Check question has text
        if question.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyQuestionText(questionNumber: index + 1))
        }

        // Check has at least 2 options (minimum for multiple choice)
        if question.options.count < 2 {
            errors.append(.insufficientOptions(questionNumber: index + 1))
        }

        // Check correct answer is within bounds
        if question.correctAnswerIndex < 0 || question.correctAnswerIndex >= question.options.count {
            errors.append(.invalidCorrectAnswer(questionNumber: index + 1))
        }

        // Check for duplicate options
        let uniqueOptions = Set(question.options.map { $0.lowercased() })
        if uniqueOptions.count != question.options.count {
            errors.append(.duplicateOptions(questionNumber: index + 1))
        }
    }

    return errors
}
```

### Timer and Time Management Edge Cases

#### Timer Expiration Handling
```swift
@State private var timeRemaining: TimeInterval
@State private var timer: Timer?
@State private var wasAutoSubmitted = false

// Timer expiration logic
private func handleTimerExpiration() {
    guard !wasAutoSubmitted else { return } // Prevent double submission

    wasAutoSubmitted = true

    // Stop timer
    timer?.invalidate()
    timer = nil

    // Auto-submit with remaining answers
    Task {
        await submitTest(autoSubmitted: true)
    }

    // Show auto-submit notification
    showAutoSubmitAlert()
}

private func showAutoSubmitAlert() {
    // Alert user that time expired and test was submitted
    let alert = UIAlertController(
        title: "Time Expired",
        message: "Your test has been automatically submitted due to time expiration.",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
}
```

#### Background/App State Transitions
```swift
// Handle app backgrounding
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { newPhase in
    switch newPhase {
    case .background, .inactive:
        // Pause timer and save current state
        timer?.invalidate()
        saveTestProgress()

    case .active:
        // Resume timer if test is still active
        if !showResults && timeRemaining > 0 {
            startTimer()
        }

    @unknown default:
        break
    }
}
```

### Answer Submission and Validation

#### Incomplete Test Submission
```swift
private func submitTest(autoSubmitted: Bool = false) async {
    let answeredCount = selectedAnswers.count
    let totalQuestions = questions.count

    // Warn about incomplete tests (unless auto-submitted)
    if !autoSubmitted && answeredCount < totalQuestions {
        let unansweredCount = totalQuestions - answeredCount
        let shouldProceed = await showIncompleteSubmissionWarning(unansweredCount: unansweredCount)

        if !shouldProceed {
            return // User chose not to submit
        }
    }

    // Proceed with submission
    await performSubmission(autoSubmitted: autoSubmitted)
}

private func showIncompleteSubmissionWarning(unansweredCount: Int) async -> Bool {
    await withCheckedContinuation { continuation in
        let alert = UIAlertController(
            title: "Incomplete Test",
            message: "You have \(unansweredCount) unanswered questions. Unanswered questions will be marked as incorrect. Do you want to submit anyway?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Submit", style: .destructive) { _ in
            continuation.resume(returning: true)
        })

        alert.addAction(UIAlertAction(title: "Continue Test", style: .cancel) { _ in
            continuation.resume(returning: false)
        })

        present(alert, animated: true)
    }
}
```

### Authentication and Authorization Errors

#### Session Expiration During Test
```swift
// Monitor authentication state
@EnvironmentObject var authService: AuthService

.onChange(of: authService.currentUser) { newUser in
    if newUser == nil && !showResults {
        // User logged out during test
        handleSessionExpiration()
    }
}

private func handleSessionExpiration() {
    // Save current progress
    saveTestProgress()

    // Show session expired alert
    let alert = UIAlertController(
        title: "Session Expired",
        message: "Your session has expired. Your progress has been saved. Please log in again to continue.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
        // Navigate back to login
        dismissToRoot()
    })

    present(alert, animated: true)
}
```

#### Permission Changes Mid-Test
```swift
// Monitor subscription status changes
@EnvironmentObject var entitlementManager: EntitlementManager

.onChange(of: entitlementManager.hasAcademyPass) { hasPass in
    if !hasPass && test.requiresSubscription && !showResults {
        // Subscription revoked during test
        handleSubscriptionRevoked()
    }
}

private func handleSubscriptionRevoked() {
    // Pause test and show subscription alert
    timer?.invalidate()

    let alert = UIAlertController(
        title: "Subscription Required",
        message: "Your subscription has been cancelled. Please renew your subscription to continue this test.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Renew", style: .default) { _ in
        // Navigate to subscription renewal
        showSubscriptionSheet = true
    })

    alert.addAction(UIAlertAction(title: "Exit Test", style: .cancel) { _ in
        // Discard progress and exit
        dismiss()
    })

    present(alert, animated: true)
}
```

### Data Synchronization Issues

#### Answer Saving Conflicts
```swift
private func saveAnswer(questionId: UUID, answerIndex: Int) async {
    do {
        // Save to local state first
        selectedAnswers[questionId] = answerIndex

        // Attempt to save to server (for real-time backup)
        try await saveAnswerToServer(questionId: questionId, answerIndex: answerIndex)

    } catch {
        // Server save failed - answer exists locally only
        // Will be saved when test is submitted
        print("Failed to save answer to server: \(error.localizedDescription)")
    }
}
```

#### Test Result Submission Conflicts
```swift
private func submitTestResult() async throws {
    let attemptNumber = try await getNextAttemptNumber()

    let result = TestResult(
        pilotId: pilotId,
        testId: testId,
        courseId: course.id,
        score: testScore,
        passed: passed,
        answers: selectedAnswers,
        attemptNumber: attemptNumber,
        completedAt: Date(),
        // ... other fields
    )

    do {
        try await supabase.from("test_results").insert(result)
    } catch let error as PostgrestError where error.code == "23505" {
        // Unique constraint violation - test already submitted
        throw TestSubmissionError.alreadySubmitted
    } catch {
        throw TestSubmissionError.networkError(error.localizedDescription)
    }
}
```

These error handling strategies ensure robust test experiences even under adverse conditions, maintaining data integrity and providing clear user guidance throughout the process.

## Performance Considerations

### Question Loading and Caching Strategy

#### Progressive Question Loading
```swift
// Load questions in batches to prevent UI blocking
private func loadQuestionsProgressively() async {
    let batchSize = 10
    var loadedQuestions: [TestQuestion] = []

    do {
        // Load first batch immediately
        let firstBatch = try await academyService.fetchTestQuestions(
            testId: testId,
            limit: batchSize,
            offset: 0
        )
        loadedQuestions.append(contentsOf: firstBatch)
        questions = loadedQuestions

        // Load remaining questions in background
        Task.detached(priority: .background) {
            do {
                let totalCount = try await getTotalQuestionCount()
                var offset = batchSize

                while offset < totalCount {
                    let batch = try await academyService.fetchTestQuestions(
                        testId: self.testId,
                        limit: batchSize,
                        offset: offset
                    )

                    await MainActor.run {
                        self.questions.append(contentsOf: batch)
                    }

                    offset += batchSize
                }
            } catch {
                print("Background question loading failed: \(error)")
            }
        }

    } catch {
        errorMessage = "Failed to load test questions"
    }
}
```

#### Memory-Efficient Image Handling
```swift
// Lazy image loading with caching
struct QuestionImageView: View {
    let imageUrl: String?
    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
            } else {
                Color.gray.opacity(0.2) // Placeholder
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // Cancel loading if view disappears
            cancelImageLoad()
        }
    }

    private func loadImage() {
        guard let urlString = imageUrl,
              let url = URL(string: urlString) else { return }

        isLoading = true

        // Check cache first
        if let cachedImage = imageCache[urlString] {
            image = cachedImage
            isLoading = false
            return
        }

        // Load from network with size limits
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let downloadedImage = UIImage(data: data),
                  let resizedImage = resizeImageIfNeeded(downloadedImage) else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }

            // Cache the image
            imageCache[urlString] = resizedImage

            DispatchQueue.main.async {
                image = resizedImage
                isLoading = false
            }
        }.resume()
    }

    private func resizeImageIfNeeded(_ image: UIImage) -> UIImage? {
        let maxDimension: CGFloat = 800
        let size = image.size

        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }
}
```

### Timer Optimization and Battery Management

#### Adaptive Timer Updates
```swift
// Reduce timer frequency when app is backgrounded
private func optimizeTimerForBattery() {
    #if os(iOS)
    // Use lower frequency timer on battery
    let timerInterval = ProcessInfo.processInfo.isLowPowerModeEnabled ? 5.0 : 1.0

    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
        self?.updateTimer()
    }
    #endif
}

private func updateTimer() {
    guard timeRemaining > 0 else {
        handleTimerExpiration()
        return
    }

    timeRemaining -= 1

    // Update display less frequently when time is high
    let shouldUpdateDisplay = timeRemaining <= 300 || // Last 5 minutes
                             timeRemaining % 60 == 0   // Every minute otherwise

    if shouldUpdateDisplay {
        updateTimerDisplay()
    }
}
```

### Database Query Optimization

#### Efficient Test Result Checking
```swift
// Use indexed queries for performance
private func checkTestPrerequisites() async -> Bool {
    guard let user = authService.currentUser else { return false }

    do {
        // Single optimized query instead of multiple calls
        let prerequisiteResults = try await supabase
            .from("test_results")
            .select("test_id, passed")
            .eq("pilot_id", value: user.id.uuidString)
            .in("test_id", values: requiredTestIds)
            .eq("passed", value: true)

        let passedTestIds = Set(prerequisiteResults.map { $0.test_id })
        return requiredTestIds.allSatisfy { passedTestIds.contains($0) }

    } catch {
        print("Error checking prerequisites: \(error)")
        return false
    }
}
```

## Testing Strategy

### Unit Testing Framework

#### Navigation Logic Testing
```swift
class TestNavigationTests: XCTestCase {

    func testMultipleChoiceNavigation() {
        let test = CourseTest(id: testId, testType: "multiple_choice", needsProctor: false, ...)
        let destination = TestRow.getNavigationDestination(test: test, isLocked: false, currentUser: mockUser)

        // Verify correct navigation to GroundSchoolTestIntroView
        XCTAssertTrue(destination is NavigationLink<GroundSchoolTestIntroView>)
    }

    func testProctoredTestNavigation() {
        let test = CourseTest(id: testId, testType: "multiple_choice", needsProctor: true, ...)
        let destination = TestRow.getNavigationDestination(test: test, isLocked: false, currentUser: mockUser)

        // Verify direct navigation to ProctorTestSchedulingView
        XCTAssertTrue(destination is NavigationLink<ProctorTestSchedulingView>)
    }

    func testFormalExamNavigation() {
        let test = CourseTest(id: testId, testType: "practical", ...)
        let destination = TestRow.getNavigationDestination(test: test, isLocked: false, currentUser: mockUser)

        // Verify navigation to ExamIntroView
        XCTAssertTrue(destination is NavigationLink<ExamIntroView>)
    }
}
```

#### Lock Condition Testing
```swift
func testLockConditions() {
    // Test subscription lock
    let subscriptionLockedTest = createTest(requiresSubscription: true)
    let userWithoutSubscription = createUser(hasSubscription: false)
    let isLocked = TestRow.isLocked(test: subscriptionLockedTest, user: userWithoutSubscription)
    XCTAssertTrue(isLocked)

    // Test prerequisite test lock
    let prerequisiteLockedTest = createTest(requiresTestPassed: true)
    let userWithoutPrerequisite = createUser(hasPassedPrerequisite: false)
    let isLocked2 = TestRow.isLocked(test: prerequisiteLockedTest, user: userWithoutPrerequisite)
    XCTAssertTrue(isLocked2)

    // Test unlocked test
    let unlockedTest = createTest(requiresSubscription: false, requiresTestPassed: false)
    let eligibleUser = createUser(hasSubscription: true, hasPassedPrerequisite: true)
    let isLocked3 = TestRow.isLocked(test: unlockedTest, user: eligibleUser)
    XCTAssertFalse(isLocked3)
}
```

#### Icon Mapping Testing
```swift
func testIconMapping() {
    let testCases = [
        ("multiple_choice", "doc.text.fill"),
        ("practical", "airplane"),
        ("oral", "antenna.radiowaves.left.and.right"),
        ("written", "pencil.and.outline")
    ]

    for (testType, expectedIcon) in testCases {
        let test = CourseTest(testType: testType, ...)
        let icon = TestCardContent(test: test, ...).testIcon
        XCTAssertEqual(icon, expectedIcon, "Icon mapping failed for \(testType)")
    }
}
```

### Integration Testing

#### Full Test Flow Testing
```swift
func testCompleteMultipleChoiceFlow() async throws {
    // Setup test environment
    let app = XCUIApplication()
    app.launch()

    // Navigate to test
    app.buttons["Ground School Test"].tap()
    XCTAssertTrue(app.staticTexts["Milestone Reached!"].exists)

    // Start test
    app.buttons["Start Test"].tap()

    // Verify test interface loads
    XCTAssertTrue(app.staticTexts["Question 1 of 70"].exists)
    XCTAssertTrue(app.buttons["Next"].exists)

    // Answer questions
    for _ in 1...5 {
        // Select random answer
        let answers = app.buttons.matching(identifier: "answer_option")
        answers.element(boundBy: 0).tap()
        app.buttons["Next"].tap()
    }

    // Submit test
    app.buttons["Submit Test"].tap()
    app.alerts.buttons["Submit"].tap()

    // Verify results screen
    XCTAssertTrue(app.staticTexts["Test Results"].exists)
    XCTAssertTrue(app.buttons["Continue"].exists)
}
```

#### Timer Functionality Testing
```swift
func testTimerExpiration() async throws {
    // Setup test with 1-minute duration
    let testView = MultipleChoiceTestView(
        testId: testId,
        durationMinutes: 1,
        // ... other params
    )

    // Wait for timer to expire
    try await Task.sleep(nanoseconds: 65_000_000_000) // 65 seconds

    // Verify auto-submission occurred
    XCTAssertTrue(testView.wasAutoSubmitted)
    XCTAssertTrue(testView.showResults)
}
```

#### Payment Flow Testing
```swift
func testProctoredTestPaymentFlow() async throws {
    // Setup Stripe test environment
    let paymentSheet = MockPaymentSheet()

    // Navigate to scheduling
    let schedulingView = ProctorTestSchedulingView(test: test, course: course, pilotId: pilotId)
    schedulingView.paymentSheet = paymentSheet

    // Fill scheduling form
    schedulingView.selectedDate = Date().adding(days: 1)
    schedulingView.selectedTime = Date().adding(hours: 10)
    schedulingView.locationType = .online

    // Submit payment
    schedulingView.canProceed = true
    try await schedulingView.processPayment()

    // Verify appointment created
    let appointment = try await supabase
        .from("exam_appointments")
        .select("*")
        .eq("pilot_id", value: pilotId.uuidString)
        .single()

    XCTAssertNotNil(appointment)
    XCTAssertEqual(appointment.status, "confirmed")
}
```

### End-to-End Testing

#### Complete User Journey Testing
```swift
func testFullAcademyExperience() async throws {
    let app = XCUIApplication()
    app.launch()

    // User authentication
    await loginUser(email: "test@pilot.com", password: "password")

    // Navigate to Academy
    app.tabBars.buttons["Academy"].tap()
    XCTAssertTrue(app.staticTexts["UAS Pilot Course"].exists)

    // Start course content
    app.buttons["UAS Pilot Course"].tap()
    XCTAssertTrue(app.staticTexts["Course Content"].exists)

    // Navigate through units
    for unitNumber in 1...4 {
        let unitButton = app.buttons["Unit \(unitNumber)"]
        XCTAssertTrue(unitButton.exists)
        unitButton.tap()

        // Complete unit (simulated)
        app.buttons["Mark as Complete"].tap()
        app.navigationBars.buttons["Back"].tap()
    }

    // Take ground school test
    app.buttons["Ground School Test"].tap()
    app.buttons["Start Test"].tap()

    // Complete test (simulated answers)
    for questionNumber in 1...70 {
        // Answer each question
        let randomAnswer = Int.random(in: 0...3)
        app.buttons["answer_\(randomAnswer)"].tap()

        if questionNumber < 70 {
            app.buttons["Next"].tap()
        }
    }

    // Submit test
    app.buttons["Submit Test"].tap()
    app.alerts.buttons["Submit"].tap()

    // Verify results and continuation
    XCTAssertTrue(app.staticTexts["Test Complete"].exists)
    XCTAssertTrue(app.buttons["Continue to Next Section"].exists)
}
```

#### Upload Flow Testing
```swift
func testFormalExamUploadFlow() async throws {
    // Navigate to exam
    let app = XCUIApplication()
    app.buttons["Flight Review"].tap()

    // Verify prerequisites checked
    XCTAssertTrue(app.staticTexts["Prerequisites"].exists)

    // Simulate file upload
    let uploadButton = app.buttons["Upload Documents"]
    uploadButton.tap()

    // Mock file picker interaction
    let filePicker = app.otherElements["file_picker"]
    filePicker.tap()

    // Select test file
    app.cells["flight_log.pdf"].tap()
    app.buttons["Upload"].tap()

    // Verify upload progress
    XCTAssertTrue(app.progressIndicators.firstMatch.exists)

    // Wait for upload completion
    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

    // Verify upload success
    XCTAssertTrue(app.staticTexts["Upload Complete"].exists)
    XCTAssertTrue(app.buttons["Submit for Review"].exists)
}
```

### Performance Testing

#### Load Testing
```swift
func testConcurrentTestTaking() async throws {
    // Simulate multiple users taking tests simultaneously
    let userCount = 50
    var tasks: [Task<Void, Error>] = []

    for userId in 1...userCount {
        let task = Task {
            try await simulateUserTestSession(userId: userId)
        }
        tasks.append(task)
    }

    // Wait for all tests to complete
    for task in tasks {
        try await task.value
    }

    // Verify no race conditions or data corruption
    let resultsCount = try await supabase
        .from("test_results")
        .select("id", count: .exact)
        .gte("completed_at", value: Date().adding(minutes: -5))

    XCTAssertEqual(resultsCount, userCount)
}
```

#### Memory Leak Testing
```swift
func testMemoryManagement() throws {
    // Test multiple test sessions without memory growth
    let initialMemory = getCurrentMemoryUsage()

    for _ in 1...10 {
        autoreleasepool {
            let testView = MultipleChoiceTestView(
                testId: testId,
                // ... params
            )
            // Simulate test interaction
            _ = testView.body
        }
    }

    let finalMemory = getCurrentMemoryUsage()
    let memoryGrowth = finalMemory - initialMemory

    // Allow small memory growth but prevent leaks
    XCTAssertLessThan(memoryGrowth, 50 * 1024 * 1024) // 50MB max growth
}
```

This comprehensive testing strategy ensures that test rendering works correctly across all scenarios, maintains performance standards, and provides a consistent experience for users on all platforms.

## Migration and Backward Compatibility

### Legacy Course Structure Support

#### Step-Based to Section-Based Migration
```swift
// Legacy system used step_number and is_mandatory fields
enum LegacyCourseStructure {
    case mandatoryUnits    // step_number = null, is_mandatory = true
    case baseProgram       // step_number = 1, is_mandatory = false
    case extensionCourses  // step_number = 2, is_mandatory = false
    case furtherTraining   // step_number = 3, is_mandatory = false
}

// New section-based system
struct CourseSection {
    let sectionType: String  // "units", "test", "exam", "recurrent"
    let requiresSubscription: Bool
    let requiresTestPassed: Bool
    let displayOrder: Int
}

// Migration mapping
private func mapLegacyToSection(unit: CourseUnit) -> CourseSection? {
    if unit.isMandatory {
        return CourseSection(
            name: "MANDATORY UNITS",
            sectionType: "units",
            requiresSubscription: false,
            requiresTestPassed: false,
            displayOrder: 1
        )
    }

    guard let stepNumber = unit.stepNumber else { return nil }

    switch stepNumber {
    case 1:
        return CourseSection(
            name: "BASE PROGRAM",
            sectionType: "units",
            requiresSubscription: false,
            requiresTestPassed: true,  // Requires Ground School Test
            displayOrder: 2
        )
    case 2:
        return CourseSection(
            name: "EXTENSION COURSES",
            sectionType: "units",
            requiresSubscription: true,  // Requires subscription
            requiresTestPassed: true,
            displayOrder: 3
        )
    case 3:
        return CourseSection(
            name: "FURTHER YOUR BASE TRAINING",
            sectionType: "units",
            requiresSubscription: true,
            requiresTestPassed: true,
            displayOrder: 4
        )
    default:
        return nil
    }
}
```

#### Fallback for Legacy Courses
```swift
private func createLegacySectionFallback(allTests: [CourseTest], allUnits: [CourseUnit]) -> [CourseSection] {
    var sections: [CourseSection] = []

    // Create sections based on available content
    if allUnits.contains(where: { $0.isMandatory }) {
        sections.append(CourseSection(
            id: UUID(),
            name: "MANDATORY UNITS",
            sectionType: "units",
            requiresSubscription: false,
            requiresTestPassed: false,
            displayOrder: 1
        ))
    }

    if allUnits.contains(where: { $0.stepNumber == 1 }) {
        sections.append(CourseSection(
            id: UUID(),
            name: "BASE PROGRAM",
            sectionType: "units",
            requiresSubscription: false,
            requiresTestPassed: true,
            displayOrder: 2
        ))
    }

    if allUnits.contains(where: { $0.stepNumber == 2 }) {
        sections.append(CourseSection(
            id: UUID(),
            name: "EXTENSION COURSES",
            sectionType: "units",
            requiresSubscription: true,
            requiresTestPassed: true,
            displayOrder: 3
        ))
    }

    // Add tests section if tests exist
    if !allTests.isEmpty {
        sections.append(CourseSection(
            id: UUID(),
            name: "COURSE TESTS",
            sectionType: "test",
            requiresSubscription: false,
            requiresTestPassed: false,
            displayOrder: sections.count + 1
        ))
    }

    return sections.sorted { $0.displayOrder < $1.displayOrder }
}
```

### Test Type Evolution and Compatibility

#### Version 1.0: Hardcoded Test Types
```swift
// Initial implementation with fixed test types
enum TestType {
    case groundSchool     // Always multiple choice, self-administered
    case flightReview     // Always practical, requires proctor
    case rocA            // Always oral/written, requires proctor
}
```

#### Version 2.0: Database-Driven Test Types
```swift
// Current implementation with flexible test configuration
struct CourseTest {
    let testType: String        // "multiple_choice", "practical", "oral", "written"
    let needsProctor: Bool      // Proctor requirement independent of type
    let duration: Int?         // Flexible duration per test
    let passingScore: Int      // Variable passing scores
    let questionSource: String // "csv" or "database"
}

// Backward compatibility mapping
private func mapLegacyTestType(test: CourseTest) -> LegacyTestType? {
    switch (test.testType, test.needsProctor) {
    case ("multiple_choice", false):
        return .groundSchool
    case ("practical", true):
        return .flightReview
    case ("oral", true), ("written", true):
        return .rocA
    default:
        return nil  // New test type, handle gracefully
    }
}
```

### Proctor Requirement Evolution

#### Phase 1: Type-Based Proctor Requirements
```swift
// Old logic: proctor requirement based on test type
private func requiresProctor_old(testType: String) -> Bool {
    switch testType {
    case "multiple_choice":
        return false  // Self-administered
    case "practical", "oral", "written":
        return true   // Always requires proctor
    default:
        return false
    }
}
```

#### Phase 2: Flexible Proctor Configuration
```swift
// New logic: proctor requirement as independent field
private func requiresProctor_new(test: CourseTest) -> Bool {
    return test.needsProctor
}

// Migration: Set proctor requirements based on existing behavior
private func migrateProctorRequirements() async {
    // Update existing tests to maintain current behavior
    try await supabase
        .from("course_tests")
        .update(["needs_proctor": false])
        .eq("test_type", value: "multiple_choice")

    try await supabase
        .from("course_tests")
        .update(["needs_proctor": true])
        .in("test_type", values: ["practical", "oral", "written"])
}
```

### Database Schema Evolution

#### Adding Section Support
```sql
-- Migration: Add section_id to course_tests
ALTER TABLE course_tests ADD COLUMN section_id UUID REFERENCES course_sections(id);

-- Migration: Add question_source for flexibility
ALTER TABLE course_tests ADD COLUMN question_source TEXT DEFAULT 'csv'
    CHECK (question_source IN ('csv', 'database'));

-- Migration: Add duration_minutes
ALTER TABLE course_tests ADD COLUMN duration INTEGER DEFAULT 60;

-- Create indexes for performance
CREATE INDEX idx_course_tests_section_id ON course_tests(section_id);
CREATE INDEX idx_course_tests_course_id_type ON course_tests(course_id, test_type);
```

#### Backward Compatibility Queries
```swift
// Handle queries for systems that don't use sections
private func getTestsForCourse_legacy(courseId: UUID) async throws -> [CourseTest] {
    // Ignore section relationships for legacy compatibility
    return try await supabase
        .from("course_tests")
        .select("*")
        .eq("course_id", value: courseId.uuidString)
        .order("order_index", ascending: true)
}

// Handle section-based queries for new systems
private func getTestsForSection(sectionId: UUID) async throws -> [CourseTest] {
    return try await supabase
        .from("course_tests")
        .select("*")
        .eq("section_id", value: sectionId.uuidString)
        .order("order_index", ascending: true)
}
```

### UI Component Evolution

#### Progressive Enhancement
```swift
// Support both legacy and modern test displays
struct AdaptiveTestRow: View {
    let test: CourseTest
    let useLegacyDisplay: Bool

    var body: some View {
        if useLegacyDisplay {
            LegacyTestCard(test: test)
        } else {
            ModernTestCard(test: test)
        }
    }
}

// Feature detection for UI capabilities
private func supportsModernUI() -> Bool {
    // Check iOS version, app version, or feature flags
    return true // Assume modern support for new installations
}
```

### Error Handling Evolution

#### Graceful Degradation
```swift
private func handleTestRenderingError(error: Error, test: CourseTest) -> some View {
    switch error {
    case TestError.unsupportedTestType:
        // Fall back to generic test display
        return GenericTestCard(test: test)

    case TestError.missingSectionData:
        // Use legacy rendering without sections
        return LegacyTestCard(test: test)

    case TestError.networkFailure:
        // Show offline-capable cached version
        return CachedTestCard(test: test)

    default:
        // Show error state with retry option
        return ErrorTestCard(test: test, error: error)
    }
}
```

### Cross-Platform Consistency

#### Shared Business Logic
```swift
// Platform-agnostic test routing logic
protocol TestRouter {
    func routeToTest(test: CourseTest, user: User) -> NavigationDestination
}

class IOSTestRouter: TestRouter {
    func routeToTest(test: CourseTest, user: User) -> NavigationDestination {
        // iOS-specific navigation logic
        switch test.testType {
        case "multiple_choice" where !test.needsProctor:
            return .view(GroundSchoolTestIntroView(course: getCourse(), onStartTest: startTest))
        // ... other cases
        }
    }
}

class WebTestRouter: TestRouter {
    func routeToTest(test: CourseTest, user: User) -> NavigationDestination {
        // Web-specific routing (React Router, etc.)
        switch test.testType {
        case "multiple_choice" where !test.needsProctor:
            return .route("/test-intro/\(test.id)")
        // ... other cases
        }
    }
}
```

#### Shared Constants and Types
```swift
// Cross-platform test type definitions
enum TestType: String {
    case multipleChoice = "multiple_choice"
    case practical = "practical"
    case oral = "oral"
    case written = "written"

    var displayIcon: String {
        switch self {
        case .multipleChoice: return "doc.text.fill"
        case .practical: return "airplane"
        case .oral: return "antenna.radiowaves.left.and.right"
        case .written: return "pencil.and.outline"
        }
    }

    var requiresUpload: Bool {
        switch self {
        case .multipleChoice: return false
        case .practical, .oral, .written: return true
        }
    }
}
```

This comprehensive migration strategy ensures that new features can be added while maintaining compatibility with existing implementations, allowing for gradual rollout of enhancements across different platforms and app versions.

This comprehensive rendering system ensures that each test type gets appropriate UI treatment while maintaining consistent user experience across different test formats and conditions.