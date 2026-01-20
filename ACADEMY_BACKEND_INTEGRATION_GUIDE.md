# Buzz Academy Backend Integration Guide

## Overview

The Buzz Academy is a comprehensive learning management system that provides drone pilot training courses, tests, and certifications. This guide documents the complete backend integration for the web version, covering courses, sections, units, tests, questions, subscriptions, and exam scheduling.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Database Schema](#database-schema)
3. [Backend API Calls](#backend-api-calls)
4. [Frontend Models](#frontend-models)
5. [Course Structure and Flow](#course-structure-and-flow)
6. [Test and Exam System](#test-and-exam-system)
7. [Subscription and Access Control](#subscription-and-access-control)
8. [Migration and Version Compatibility](#migration-and-version-compatibility)

## Architecture Overview

### Core Components

- **Courses**: Training programs with structured content
- **Sections**: Course organization units (mandatory units, base program, extensions, etc.)
- **Units**: Individual learning modules with content and materials
- **Tests**: Assessment components (multiple choice, practical, oral exams)
- **Questions**: Test questions with multiple choice answers
- **Subscriptions**: Access control for premium content
- **Exam Appointments**: Scheduled proctored examinations

### Data Flow

```
Frontend (Web/iOS) ↔ Supabase ↔ Edge Functions ↔ Stripe/ZOOM
     ↓
   Database Tables
     ↓
  Row Level Security
```

## Database Schema

### Core Tables

#### `training_courses`
Main course catalog with metadata and prerequisites.

```sql
CREATE TABLE public.training_courses (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  description text NOT NULL,
  duration text NOT NULL,
  level text NOT NULL CHECK (level = ANY (ARRAY['Beginner'::text, 'Intermediate'::text, 'Advanced'::text])),
  category text DEFAULT 'General'::text CHECK (category = ANY (ARRAY['Mandatory'::text, 'Extension'::text, 'Intermediate'::text, 'Advanced'::text, 'Specialized'::text, 'General'::text])),
  instructor text NOT NULL,
  rating double precision DEFAULT 0.0,
  students_count integer DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  provider text DEFAULT 'Buzz'::text CHECK (provider = ANY (ARRAY['Buzz'::text, 'Red Cross'::text, 'USFA'::text, 'FEMA'::text, 'Amazon'::text, 'T-Mobile'::text, 'Other'::text])),
  instructor_picture_url text,
  requires_uas_ground_school boolean DEFAULT false,
  requires_flight_review_passed boolean DEFAULT false,
  requires_roc_a_passed boolean DEFAULT false,
  external_url text,
  cover_image_url text,
  region text DEFAULT 'Global'::text CHECK (region = ANY (ARRAY['Canada'::text, 'USA'::text, 'UK'::text, 'Australia'::text, 'New Zealand'::text, 'South Africa'::text, 'Global'::text])),
  active boolean DEFAULT false,
  CONSTRAINT training_courses_pkey PRIMARY KEY (id)
);
```

#### `course_sections`
Configurable course structure for organizing units and tests.

```sql
CREATE TABLE public.course_sections (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,
  name text NOT NULL,
  display_order integer NOT NULL,
  description text,
  section_type text DEFAULT 'units'::text,
  requires_subscription boolean DEFAULT false,
  requires_test_passed boolean DEFAULT false,
  prerequisite_section_id uuid,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  exam_type text CHECK (exam_type IS NULL OR (exam_type = ANY (ARRAY['flight_review'::text, 'roc_a'::text]))),
  CONSTRAINT course_sections_pkey PRIMARY KEY (id),
  CONSTRAINT course_sections_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id),
  CONSTRAINT course_sections_prerequisite_fkey FOREIGN KEY (prerequisite_section_id) REFERENCES public.course_sections(id)
);
```

#### `course_units`
Individual learning modules with content and materials.

```sql
CREATE TABLE public.course_units (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,
  unit_number integer NOT NULL,
  title text NOT NULL,
  description text,
  content text,
  step_number integer,
  is_mandatory boolean DEFAULT false,
  order_index integer NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  pdf_url jsonb,
  section_id uuid,
  prerequisite_units ARRAY,
  prerequisite_tests ARRAY,
  pdf_names jsonb,
  material_urls jsonb DEFAULT '[]'::jsonb,
  material_names jsonb DEFAULT '[]'::jsonb,
  material_types jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT course_units_pkey PRIMARY KEY (id),
  CONSTRAINT course_units_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id),
  CONSTRAINT course_units_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.course_sections(id)
);
```

#### `course_tests`
Test definitions and configurations.

```sql
CREATE TABLE public.course_tests (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,
  test_name text NOT NULL,
  test_description text,
  test_type text NOT NULL DEFAULT 'multiple_choice'::text CHECK (test_type = ANY (ARRAY['multiple_choice'::text, 'practical'::text, 'written'::text, 'oral'::text])),
  passing_score integer NOT NULL DEFAULT 70 CHECK (passing_score >= 0 AND passing_score <= 100),
  required_for_progression boolean DEFAULT true,
  required_units ARRAY,
  order_index integer NOT NULL DEFAULT 0,
  questions jsonb,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  section_id uuid,
  question_source text DEFAULT 'csv'::text CHECK (question_source = ANY (ARRAY['csv'::text, 'database'::text])),
  needs_proctor boolean DEFAULT false,
  duration integer NOT NULL DEFAULT 60,
  price_of_schedule integer CHECK (price_of_schedule IS NULL OR price_of_schedule >= 0 AND price_of_schedule <= 50000),
  CONSTRAINT course_tests_pkey PRIMARY KEY (id),
  CONSTRAINT course_tests_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id),
  CONSTRAINT course_tests_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.course_sections(id)
);
```

#### `test_questions`
Individual test questions with answers and explanations.

```sql
CREATE TABLE public.test_questions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  test_id uuid NOT NULL,
  question_number integer NOT NULL,
  question_area text,
  question_text text NOT NULL,
  options jsonb NOT NULL DEFAULT '[]'::jsonb,
  correct_answer_index integer NOT NULL CHECK (correct_answer_index >= 0),
  explanation text,
  image_urls ARRAY DEFAULT '{}'::text[],
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  problem_sets ARRAY,
  CONSTRAINT test_questions_pkey PRIMARY KEY (id),
  CONSTRAINT test_questions_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.course_tests(id)
);
```

#### `test_results`
Test attempt records and results.

```sql
CREATE TABLE public.test_results (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  test_id uuid NOT NULL,
  course_id uuid NOT NULL,
  score integer NOT NULL CHECK (score >= 0 AND score <= 100),
  passed boolean NOT NULL DEFAULT false,
  answers jsonb,
  attempt_number integer DEFAULT 1,
  completed_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  result_file_urls ARRAY DEFAULT '{}'::text[],
  upload_status text DEFAULT 'not_submitted'::text CHECK (upload_status = ANY (ARRAY['not_submitted'::text, 'pending'::text, 'approved'::text, 'rejected'::text])),
  uploaded_at timestamp with time zone,
  reviewed_at timestamp with time zone,
  reviewer_notes text,
  reviewed_by uuid,
  proctor_name text,
  CONSTRAINT test_results_pkey PRIMARY KEY (id),
  CONSTRAINT test_results_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT test_results_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.course_tests(id),
  CONSTRAINT test_results_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id),
  CONSTRAINT test_results_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.profiles(id)
);
```

#### `exam_appointments`
Scheduled proctored exam appointments.

```sql
CREATE TABLE public.exam_appointments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  exam_type text NOT NULL CHECK (exam_type = ANY (ARRAY['flight_review'::text, 'roc_a'::text])),
  scheduled_date timestamp with time zone NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 15,
  location_type text NOT NULL CHECK (location_type = ANY (ARRAY['in_person'::text, 'online'::text])),
  location_address text,
  meeting_link text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'completed'::text, 'cancelled'::text])),
  stripe_payment_intent_id text,
  stripe_charge_id text,
  payment_amount numeric NOT NULL,
  notes text,
  examiner_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  zoom_meeting_id text,
  zoom_meeting_password text,
  CONSTRAINT exam_appointments_pkey PRIMARY KEY (id),
  CONSTRAINT exam_appointments_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT exam_appointments_examiner_id_fkey FOREIGN KEY (examiner_id) REFERENCES public.profiles(id)
);
```

#### `course_enrollments`
User course enrollment tracking.

```sql
CREATE TABLE public.course_enrollments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  course_id uuid NOT NULL,
  enrolled_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  completed_at timestamp with time zone,
  progress_percentage integer DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  CONSTRAINT course_enrollments_pkey PRIMARY KEY (id),
  CONSTRAINT course_enrollments_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT course_enrollments_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
```

#### `unit_completions`
Individual unit completion tracking.

```sql
CREATE TABLE unit_completions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  unit_id UUID REFERENCES course_units(id) ON DELETE CASCADE,
  course_id UUID REFERENCES training_courses(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### `course_subscriptions`
Subscription management for premium course access.

```sql
CREATE TABLE public.course_subscriptions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  pilot_id uuid NOT NULL,
  course_id uuid NOT NULL,
  stripe_subscription_id text,
  stripe_price_id text,
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'canceled'::text, 'past_due'::text, 'incomplete'::text, 'trialing'::text])),
  current_period_start timestamp with time zone,
  current_period_end timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT course_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT course_subscriptions_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT course_subscriptions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id)
);
```

#### `exam_type_config`
Configuration for different exam types.

```sql
CREATE TABLE public.exam_type_config (
  exam_type text NOT NULL CHECK (exam_type = ANY (ARRAY['flight_review'::text, 'roc_a'::text])),
  display_name text NOT NULL,
  short_description text NOT NULL,
  full_description text NOT NULL,
  icon text NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 30,
  allows_online boolean NOT NULL DEFAULT false,
  stripe_product_id text NOT NULL,
  prerequisites jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT exam_type_config_pkey PRIMARY KEY (exam_type)
);
```

## Backend API Calls

### Course Management

#### Fetch All Courses
```typescript
// GET /training_courses?active=eq.true&order=created_at.desc
const { data: courses } = await supabase
  .from('training_courses')
  .select('*')
  .eq('active', true)
  .order('created_at', { ascending: false });
```

#### Fetch Courses with Enrollment Status
```typescript
// Get courses with enrollment status for a specific pilot
async function fetchCoursesWithEnrollment(pilotId: string) {
  // 1. Fetch all active courses
  const { data: courses } = await supabase
    .from('training_courses')
    .select('*')
    .eq('active', true)
    .order('created_at', { ascending: false });

  // 2. Fetch user's enrollments
  const { data: enrollments } = await supabase
    .from('course_enrollments')
    .select('course_id, completed_at')
    .eq('pilot_id', pilotId);

  // 3. Merge enrollment data
  const enrolledCourseIds = new Set(enrollments?.map(e => e.course_id) || []);
  return courses?.map(course => ({
    ...course,
    isEnrolled: enrolledCourseIds.has(course.id)
  }));
}
```

#### Fetch Course Sections
```typescript
// GET /course_sections?course_id=eq.{courseId}&order=display_order.asc
const { data: sections } = await supabase
  .from('course_sections')
  .select('*')
  .eq('course_id', courseId)
  .order('display_order', { ascending: true });
```

#### Fetch Units for Course
```typescript
// GET /course_units?course_id=eq.{courseId}&order=order_index.asc
const { data: units } = await supabase
  .from('course_units')
  .select('*')
  .eq('course_id', courseId)
  .order('order_index', { ascending: true });
```

#### Fetch Units for Section
```typescript
// GET /course_units?section_id=eq.{sectionId}&order=order_index.asc
const { data: units } = await supabase
  .from('course_units')
  .select('*')
  .eq('section_id', sectionId)
  .order('order_index', { ascending: true });
```

### Test Management

#### Fetch Course Tests
```typescript
// GET /course_tests?course_id=eq.{courseId}&is_active=eq.true&order=order_index.asc
const { data: tests } = await supabase
  .from('course_tests')
  .select('*')
  .eq('course_id', courseId)
  .eq('is_active', true)
  .order('order_index', { ascending: true });
```

#### Fetch Test Questions
```typescript
// GET /test_questions?test_id=eq.{testId}&order=question_number.asc
const { data: questions } = await supabase
  .from('test_questions')
  .select('*')
  .eq('test_id', testId)
  .order('question_number', { ascending: true });
```

#### Fetch Test Results for User
```typescript
// GET /test_results?pilot_id=eq.{pilotId}&test_id=eq.{testId}&order=completed_at.desc
const { data: results } = await supabase
  .from('test_results')
  .select('*')
  .eq('pilot_id', pilotId)
  .eq('test_id', testId)
  .order('completed_at', { ascending: false });
```

### Progress Tracking

#### Check Unit Completion
```typescript
// GET /unit_completions?pilot_id=eq.{pilotId}&unit_id=eq.{unitId}
const { data: completion } = await supabase
  .from('unit_completions')
  .select('id')
  .eq('pilot_id', pilotId)
  .eq('unit_id', unitId);

const isCompleted = completion && completion.length > 0;
```

#### Mark Unit as Completed
```typescript
// POST /unit_completions
const { data } = await supabase
  .from('unit_completions')
  .insert({
    pilot_id: pilotId,
    unit_id: unitId,
    course_id: courseId
  })
  .select();
```

#### Check Test Status
```typescript
// GET /test_results?pilot_id=eq.{pilotId}&test_id=eq.{testId}&passed=eq.true
const { data: passedResults } = await supabase
  .from('test_results')
  .select('id')
  .eq('pilot_id', pilotId)
  .eq('test_id', testId)
  .eq('passed', true);

const hasPassed = passedResults && passedResults.length > 0;
```

### Subscription Management

#### Check Subscription Status
```typescript
// GET /course_subscriptions?pilot_id=eq.{pilotId}&course_id=eq.{courseId}&status=eq.active
const { data: subscription } = await supabase
  .from('course_subscriptions')
  .select('*')
  .eq('pilot_id', pilotId)
  .eq('course_id', courseId)
  .eq('status', 'active');

const hasActiveSubscription = subscription && subscription.length > 0;
```

#### Create Course Enrollment
```typescript
// POST /course_enrollments
const { data } = await supabase
  .from('course_enrollments')
  .insert({
    pilot_id: pilotId,
    course_id: courseId
  });
```

### Exam Scheduling

#### Fetch Exam Price
```typescript
// Call Edge Function: get-exam-price
const { data } = await supabase.functions.invoke('get-exam-price', {
  body: { product_id: stripeProductId }
});

// Response: { unit_amount: 9900, currency: 'usd', product_name: 'Flight Review Exam' }
```

#### Create Exam Payment Intent
```typescript
// Call Edge Function: create-exam-payment
const { data } = await supabase.functions.invoke('create-exam-payment', {
  body: {
    product_id: stripeProductId,
    pilot_id: pilotId,
    exam_type: 'flight_review',
    scheduled_date: '2024-01-20T10:00:00Z',
    location_type: 'online',
    location_address: null
  }
});

// Response: { client_secret: '...', payment_intent_id: '...', amount: 9900 }
```

#### Create Exam Appointment
```typescript
// POST /exam_appointments (after successful payment)
const { data } = await supabase
  .from('exam_appointments')
  .insert({
    pilot_id: pilotId,
    exam_type: 'flight_review',
    scheduled_date: scheduledDate,
    duration_minutes: 60,
    location_type: 'online',
    meeting_link: zoomMeetingLink,
    status: 'confirmed',
    stripe_payment_intent_id: paymentIntentId,
    payment_amount: 99.00
  });
```

## Frontend Models

### Core Models

#### TrainingCourse
```typescript
interface TrainingCourse {
  id: string;
  title: string;
  description: string;
  duration: string;
  level: 'Beginner' | 'Intermediate' | 'Advanced';
  category: 'Mandatory' | 'Extension' | 'Intermediate' | 'Advanced' | 'Specialized';
  instructor: string;
  instructorPictureUrl?: string;
  rating: number;
  studentsCount: number;
  isEnrolled: boolean;
  provider: 'Buzz' | 'Red Cross' | 'USFA' | 'FEMA' | 'Amazon' | 'T-Mobile' | 'Other';
  badgeId?: string;
  isRecurrent: boolean;
  recurrentDueDate?: Date;
  requiresUasGroundSchool: boolean;
  requiresFlightReviewPassed: boolean;
  requiresRocAPassed: boolean;
  externalUrl?: string;
  coverImageUrl?: string;
  region: CourseRegion;
  active: boolean;
}
```

#### CourseSection
```typescript
interface CourseSection {
  id: string;
  courseId: string;
  name: string;
  displayOrder: number;
  description?: string;
  sectionType: 'units' | 'test' | 'recurrent' | 'exam';
  requiresSubscription: boolean;
  requiresTestPassed: boolean;
  prerequisiteSectionId?: string;
  isActive: boolean;
  examType?: 'flight_review' | 'roc_a';
}
```

#### CourseUnit
```typescript
interface CourseUnit {
  id: string;
  courseId: string;
  unitNumber: number;
  title: string;
  description?: string;
  content?: string;
  // New multi-format material support
  materialUrls: string[];
  materialNames: string[];
  materialTypes: string[];
  // Legacy support
  pdfUrls: string[];
  pdfNames: string[];
  sectionId?: string;
  orderIndex: number;
  prerequisiteUnits?: number[];
  prerequisiteTests?: string[];
}

interface CourseMaterial {
  index: number;
  url: string;
  name: string;
  type: string; // 'pdf', 'jpeg', 'png', etc.
  isPDF: boolean;
  isImage: boolean;
}
```

#### CourseTest
```typescript
interface CourseTest {
  id: string;
  courseId: string;
  testName: string;
  testDescription?: string;
  testType: 'multiple_choice' | 'oral' | 'practical';
  passingScore: number;
  duration?: number; // minutes
  requiredForProgression: boolean;
  requiredUnits: number[];
  orderIndex: number;
  isActive: boolean;
  sectionId?: string;
  needsProctor: boolean;
  priceOfSchedule?: number; // cents
}

interface TestQuestion {
  id: string;
  testId: string;
  questionNumber: number;
  questionArea?: string;
  questionText: string;
  options: string[];
  correctAnswerIndex: number;
  explanation?: string;
  imageUrls: string[];
  problemSets?: number[];
}

interface TestResult {
  id: string;
  pilotId: string;
  testId: string;
  courseId: string;
  score: number;
  passed: boolean;
  answers?: Record<string, number>;
  attemptNumber: number;
  completedAt: Date;
  resultFileUrls?: string[];
  uploadStatus?: 'not_submitted' | 'pending' | 'approved' | 'rejected';
  uploadedAt?: Date;
  reviewedAt?: Date;
  reviewerNotes?: string;
  reviewedBy?: string;
  proctorName?: string;
}
```

#### ExamAppointment
```typescript
interface ExamAppointment {
  id: string;
  pilotId: string;
  examType: 'flight_review' | 'roc_a';
  scheduledDate: Date;
  durationMinutes: number;
  locationType: 'online' | 'in_person';
  locationAddress?: string;
  meetingLink?: string;
  zoomMeetingId?: string;
  zoomMeetingPassword?: string;
  status: 'pending' | 'confirmed' | 'completed' | 'cancelled';
  stripePaymentIntentId?: string;
  stripeChargeId?: string;
  paymentAmount: number;
  notes?: string;
  examinerId?: string;
}
```

## Course Structure and Flow

### UAS Pilot Course Flow

The UAS Pilot Course follows a structured progression:

1. **MANDATORY UNITS** (Free, Units 1-4)
   - No prerequisites
   - Basic drone knowledge
   - Must complete Unit 4 to unlock tests

2. **GROUND SCHOOL TEST** (Free)
   - Prerequisites: Unit 4 completed
   - Multiple choice questions
   - Passing unlocks Base Program

3. **BASE PROGRAM** (Free, Units 5-10)
   - Prerequisites: Ground School Test passed
   - Advanced drone operations
   - Must complete all units to unlock extensions

4. **RECURRENT TRAINING** (Paid)
   - Prerequisites: Ground School Test passed + Active subscription
   - Annual renewal training

5. **EXTENSION COURSES** (Paid)
   - Prerequisites: Ground School Test passed + Active subscription
   - Specialized training modules

6. **FURTHER YOUR BASE TRAINING** (Paid)
   - Prerequisites: Ground School Test passed + Active subscription
   - Advanced specialized content

### Section-Based Access Control

```typescript
function canAccessSection(section: CourseSection, userProgress: UserProgress): boolean {
  // Check subscription requirement
  if (section.requiresSubscription && !userProgress.hasActiveSubscription) {
    return false;
  }

  // Check test prerequisite
  if (section.requiresTestPassed) {
    const groundSchoolTestId = 'ground-school-test-id';
    if (!userProgress.passedTests.includes(groundSchoolTestId)) {
      return false;
    }
  }

  // Check prerequisite section
  if (section.prerequisiteSectionId) {
    const prereqSection = userProgress.completedSections.includes(section.prerequisiteSectionId);
    if (!prereqSection) {
      return false;
    }
  }

  return true;
}
```

### Unit Completion Logic

```typescript
async function markUnitCompleted(unitId: string, pilotId: string, courseId: string) {
  // Check prerequisites
  if (!await checkUnitPrerequisites(unitId, pilotId)) {
    throw new Error('Prerequisites not met');
  }

  // Mark unit as completed
  await supabase.from('unit_completions').insert({
    pilot_id: pilotId,
    unit_id: unitId,
    course_id: courseId
  });

  // Update course progress
  await updateCourseProgress(courseId, pilotId);
}
```

## Test and Exam System

### Test Types

1. **Multiple Choice Tests**
   - Self-paced
   - Immediate scoring
   - No proctor required

2. **Oral Exams**
   - Scheduled appointments
   - Video conferencing with proctor
   - Manual grading

3. **Practical Exams**
   - In-person or supervised
   - Flight demonstrations
   - Manual evaluation

### Problem Set Randomization

For comprehensive testing, questions can be grouped into problem sets:

```typescript
function filterQuestionsByProblemSet(questions: TestQuestion[]): TestQuestion[] {
  // Find questions with problem sets
  const questionsWithSets = questions.filter(q => q.problemSets?.length);

  if (!questionsWithSets.length) {
    return questions; // No problem sets, return all
  }

  // Get all unique problem set numbers
  const allSets = new Set<number>();
  questionsWithSets.forEach(q => q.problemSets?.forEach(set => allSets.add(set)));

  // Randomly select one problem set
  const selectedSet = Array.from(allSets)[Math.floor(Math.random() * allSets.size)];

  // Return questions from selected set + questions without problem sets
  return questions.filter(q =>
    !q.problemSets?.length || q.problemSets.includes(selectedSet)
  );
}
```

### Test Result Processing

```typescript
async function submitTestResult(testId: string, answers: Record<string, number>, pilotId: string) {
  // Calculate score
  const questions = await fetchTestQuestions(testId);
  const correctAnswers = answers.filter((answerIndex, questionNum) => {
    const question = questions.find(q => q.questionNumber === questionNum);
    return question?.correctAnswerIndex === answerIndex;
  });

  const score = Math.round((correctAnswers.length / questions.length) * 100);
  const passed = score >= test.passingScore;

  // Get attempt number
  const previousAttempts = await supabase
    .from('test_results')
    .select('attempt_number')
    .eq('pilot_id', pilotId)
    .eq('test_id', testId)
    .order('attempt_number', { ascending: false })
    .limit(1);

  const attemptNumber = (previousAttempts[0]?.attempt_number || 0) + 1;

  // Save result
  await supabase.from('test_results').insert({
    pilot_id: pilotId,
    test_id: testId,
    course_id: test.courseId,
    score,
    passed,
    answers,
    attempt_number: attemptNumber
  });

  return { score, passed, attemptNumber };
}
```

### Exam Scheduling Flow

```typescript
async function scheduleExam(examType: ExamType, pilotId: string, scheduledDate: Date) {
  // 1. Check prerequisites
  const prerequisites = await checkExamPrerequisites(examType, pilotId);
  if (!prerequisites.met) {
    throw new Error(`Prerequisites not met: ${prerequisites.missing.join(', ')}`);
  }

  // 2. Check for existing appointments
  const existing = await supabase
    .from('exam_appointments')
    .select('id')
    .eq('pilot_id', pilotId)
    .eq('exam_type', examType)
    .in('status', ['pending', 'confirmed']);

  if (existing.length > 0) {
    throw new Error('You already have a pending or confirmed appointment for this exam');
  }

  // 3. Get exam price
  const priceResponse = await supabase.functions.invoke('get-exam-price', {
    body: { product_id: getExamProductId(examType) }
  });

  // 4. Create payment intent
  const paymentResponse = await supabase.functions.invoke('create-exam-payment', {
    body: {
      product_id: getExamProductId(examType),
      pilot_id: pilotId,
      exam_type: examType,
      scheduled_date: scheduledDate.toISOString(),
      location_type: 'online'
    }
  });

  return {
    clientSecret: paymentResponse.clientSecret,
    paymentIntentId: paymentResponse.paymentIntentId,
    amount: priceResponse.unit_amount
  };
}
```

## Subscription and Access Control

### Subscription Sources

The system supports multiple subscription sources:

1. **Apple App Store** - iOS in-app purchases
2. **Stripe** - Web payments and subscriptions
3. **Legacy** - Existing subscriptions without source tracking

### Access Control Logic

```typescript
function hasAccessToContent(
  contentType: 'unit' | 'section',
  content: CourseUnit | CourseSection,
  userStatus: UserStatus
): boolean {
  // Free content (units 1-4)
  if (contentType === 'unit' && (content as CourseUnit).unitNumber <= 4) {
    return true;
  }

  // Check active subscription
  if (!userStatus.hasActiveSubscription) {
    return false;
  }

  // Check content-specific requirements
  if (contentType === 'section') {
    const section = content as CourseSection;
    if (section.requiresTestPassed && !userStatus.hasPassedGroundSchool) {
      return false;
    }
  }

  return true;
}
```

### Subscription Management

```typescript
async function createSubscription(pilotId: string, courseId: string, source: 'apple' | 'stripe') {
  if (source === 'apple') {
    // Handle Apple subscription
    await supabase.from('course_subscriptions').insert({
      pilot_id: pilotId,
      course_id: courseId,
      status: 'active',
      source: 'apple',
      current_period_start: new Date(),
      current_period_end: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) // 1 year
    });
  } else {
    // Handle Stripe subscription via webhook
    // Subscription created via Stripe webhook
  }
}

async function checkSubscriptionStatus(pilotId: string, courseId: string): Promise<boolean> {
  const { data } = await supabase
    .from('course_subscriptions')
    .select('status')
    .eq('pilot_id', pilotId)
    .eq('course_id', courseId)
    .eq('status', 'active')
    .single();

  return !!data;
}
```

## Migration and Version Compatibility

### Material File Types Migration

The system recently migrated from single PDF support to multi-format material support:

```sql
-- Add new columns for multi-format support
ALTER TABLE course_units ADD COLUMN material_urls jsonb DEFAULT '[]'::jsonb;
ALTER TABLE course_units ADD COLUMN material_names jsonb DEFAULT '[]'::jsonb;
ALTER TABLE course_units ADD COLUMN material_types jsonb DEFAULT '[]'::jsonb;

-- Migrate existing data
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT id, pdf_url, pdf_names FROM course_units
    LOOP
        -- Migrate single PDF URL to array format
        IF rec.pdf_url IS NOT NULL THEN
            UPDATE course_units
            SET material_urls = jsonb_build_array(rec.pdf_url),
                material_names = COALESCE(rec.pdf_names, jsonb_build_array('Course Material')),
                material_types = jsonb_build_array('pdf')
            WHERE id = rec.id;
        END IF;
    END LOOP;
END $$;
```

### Backward Compatibility

```typescript
// Frontend handles both old and new material formats
function getMaterials(unit: CourseUnit): CourseMaterial[] {
  // Prefer new format
  if (unit.materialUrls?.length > 0) {
    return unit.materialUrls.map((url, index) => ({
      url,
      name: unit.materialNames?.[index] || `Material ${index + 1}`,
      type: unit.materialTypes?.[index] || 'pdf'
    }));
  }

  // Fall back to legacy PDF format
  if (unit.pdfUrls?.length > 0) {
    return unit.pdfUrls.map((url, index) => ({
      url,
      name: unit.pdfNames?.[index] || `Material ${index + 1}`,
      type: 'pdf'
    }));
  }

  return [];
}
```

### Section-Based Migration

The system migrated from step-based to section-based organization:

```typescript
// Legacy: step_number based
const units = await supabase
  .from('course_units')
  .select('*')
  .eq('course_id', courseId)
  .eq('step_number', 1);

// New: section_id based
const units = await supabase
  .from('course_units')
  .select('*')
  .eq('section_id', sectionId)
  .order('order_index');
```

### API Version Compatibility

```typescript
// Handle both old and new field names in API responses
function normalizeUnit(unit: any): CourseUnit {
  return {
    ...unit,
    // Handle section_id vs step_number
    sectionId: unit.section_id || null,
    stepNumber: unit.step_number || null,
    // Handle material fields
    materialUrls: unit.material_urls || [],
    materialNames: unit.material_names || [],
    materialTypes: unit.material_types || [],
    // Legacy fields
    pdfUrls: unit.pdf_urls || unit.pdf_url ? [unit.pdf_url] : [],
    pdfNames: unit.pdf_names || []
  };
}
```

## Integration Checklist for Web Version

### Phase 1: Core Course Display
- [ ] Implement course catalog fetching
- [ ] Add course filtering (category, provider, region)
- [ ] Display course enrollment status
- [ ] Implement course enrollment/unenrollment

### Phase 2: Course Content
- [ ] Implement section-based navigation
- [ ] Add unit content display
- [ ] Support multi-format materials (PDF, images)
- [ ] Implement unit completion tracking
- [ ] Add prerequisite checking

### Phase 3: Testing System
- [ ] Implement multiple choice test interface
- [ ] Add test question randomization (problem sets)
- [ ] Implement test result submission and scoring
- [ ] Add test attempt tracking
- [ ] Display test results and explanations

### Phase 4: Subscription Management
- [ ] Implement Stripe subscription handling
- [ ] Add access control for premium content
- [ ] Implement subscription status checking
- [ ] Add subscription renewal notifications

### Phase 5: Exam Scheduling
- [ ] Implement exam type configuration fetching
- [ ] Add Stripe payment integration for exams
- [ ] Implement Zoom meeting creation for online exams
- [ ] Add appointment scheduling and management
- [ ] Implement exam confirmation emails

### Phase 6: Progress and Analytics
- [ ] Add course progress tracking
- [ ] Implement completion certificates
- [ ] Add learning analytics
- [ ] Implement recurrent training notifications

## Error Handling

### Common Error Scenarios

1. **Network Failures**
   ```typescript
   try {
     const data = await supabase.from('courses').select('*');
   } catch (error) {
     if (error.message.includes('network')) {
       showOfflineMessage();
     }
   }
   ```

2. **Permission Denied**
   ```typescript
   if (error.code === 'PGRST116') {
     // Row Level Security violation
     redirectToLogin();
   }
   ```

3. **Prerequisite Not Met**
   ```typescript
   if (!await checkPrerequisites(unitId, pilotId)) {
     showError('Complete required units first');
   }
   ```

4. **Subscription Required**
   ```typescript
   if (!hasActiveSubscription) {
     showSubscriptionPrompt();
   }
   ```

## Performance Optimization

### Query Optimization
- Use appropriate indexes on frequently queried columns
- Implement pagination for large result sets
- Cache exam configurations and course metadata

### Data Fetching Strategies
- Prefetch course sections and units for better UX
- Lazy load test questions when needed
- Implement optimistic updates for better responsiveness

### Real-time Updates
- Subscribe to course progress changes
- Listen for subscription status updates
- Monitor exam appointment status changes

---

This guide provides comprehensive documentation for integrating the Buzz Academy system into the web version. The iOS implementation serves as the reference implementation, ensuring feature parity across platforms.