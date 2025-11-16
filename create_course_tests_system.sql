-- Create Course Tests System
-- This creates a scalable test system that works for any course
-- Run this SQL in your Supabase SQL Editor

-- ============================================================================
-- TABLE 1: course_tests
-- Defines tests for courses (metadata about each test)
-- ============================================================================
CREATE TABLE IF NOT EXISTS course_tests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES training_courses(id) ON DELETE CASCADE NOT NULL,
    test_name TEXT NOT NULL,
    test_description TEXT,
    test_type TEXT NOT NULL DEFAULT 'multiple_choice' CHECK (test_type IN ('multiple_choice', 'practical', 'written', 'oral')),
    passing_score INTEGER NOT NULL DEFAULT 70 CHECK (passing_score >= 0 AND passing_score <= 100),
    required_for_progression BOOLEAN DEFAULT TRUE, -- Does passing this test unlock next units?
    required_units INTEGER[], -- Array of unit numbers that should be completed before taking test
    order_index INTEGER NOT NULL DEFAULT 0, -- Order of test in course (if multiple tests)
    questions JSONB, -- Store questions or question IDs
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(course_id, order_index)
);

-- Enable Row Level Security
ALTER TABLE course_tests ENABLE ROW LEVEL SECURITY;

-- RLS Policies for course_tests (anyone authenticated can view tests)
DROP POLICY IF EXISTS "Anyone can view active course tests" ON course_tests;
CREATE POLICY "Anyone can view active course tests" 
    ON course_tests FOR SELECT 
    TO authenticated
    USING (is_active = true);

-- ============================================================================
-- TABLE 2: test_results
-- Stores all test results for all tests across all courses
-- ============================================================================
CREATE TABLE IF NOT EXISTS test_results (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    test_id UUID REFERENCES course_tests(id) ON DELETE CASCADE NOT NULL,
    course_id UUID REFERENCES training_courses(id) ON DELETE CASCADE NOT NULL,
    score INTEGER NOT NULL CHECK (score >= 0 AND score <= 100),
    passed BOOLEAN NOT NULL DEFAULT FALSE,
    answers JSONB, -- Store the pilot's answers
    attempt_number INTEGER DEFAULT 1, -- Track which attempt this is
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(pilot_id, test_id) -- One result per pilot per test (latest attempt)
);

-- If you want to track ALL attempts (not just latest), remove the UNIQUE constraint
-- and add: CREATE INDEX idx_test_results_attempts ON test_results(pilot_id, test_id, attempt_number);

-- Enable Row Level Security
ALTER TABLE test_results ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own test results" ON test_results;
DROP POLICY IF EXISTS "Pilots can insert their own test results" ON test_results;
DROP POLICY IF EXISTS "Pilots can update their own test results" ON test_results;

-- RLS Policies for test_results
CREATE POLICY "Pilots can view their own test results" 
    ON test_results FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own test results" 
    ON test_results FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can update their own test results" 
    ON test_results FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- ============================================================================
-- INDEXES for better query performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_course_tests_course_id ON course_tests(course_id);
CREATE INDEX IF NOT EXISTS idx_course_tests_active ON course_tests(is_active);
CREATE INDEX IF NOT EXISTS idx_test_results_pilot_test ON test_results(pilot_id, test_id);
CREATE INDEX IF NOT EXISTS idx_test_results_pilot_course ON test_results(pilot_id, course_id);
CREATE INDEX IF NOT EXISTS idx_test_results_course ON test_results(course_id);

-- ============================================================================
-- INSERT GROUND SCHOOL TEST for UAS Pilot Course
-- ============================================================================

-- First, let's create the Ground School Test definition
INSERT INTO course_tests (
    id,
    course_id,
    test_name,
    test_description,
    test_type,
    passing_score,
    required_for_progression,
    required_units,
    order_index,
    questions,
    is_active
) VALUES (
    'a1b2c3d4-e5f6-7890-abcd-000000000001'::uuid, -- Fixed UUID for Ground School Test
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, -- UAS Pilot Course ID
    'Ground School Test',
    'Comprehensive test covering Units 1-3: Ground School, Health & Safety, and Operations',
    'multiple_choice',
    70,
    true, -- Required for progression to Step 1
    ARRAY[1, 2, 3], -- Must complete Units 1, 2, 3 first
    0, -- First test in the course
    '{
        "questions": [
            {
                "id": 1,
                "question": "A small UA causes an accident and your crew member loses consciousness. When do you report the accident?",
                "options": [
                    "No accidents need to be reported.",
                    "When requested by the UA owner.",
                    "Within 10 days of the accident."
                ],
                "correctAnswer": 2
            }
        ]
    }'::jsonb,
    true
)
ON CONFLICT (id) DO UPDATE SET
    test_name = EXCLUDED.test_name,
    test_description = EXCLUDED.test_description,
    passing_score = EXCLUDED.passing_score,
    required_for_progression = EXCLUDED.required_for_progression,
    required_units = EXCLUDED.required_units,
    questions = EXCLUDED.questions,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- ============================================================================
-- MIGRATION: Move existing ground_school_test_results to new structure
-- ============================================================================

-- If you already have the old ground_school_test_results table with data, 
-- uncomment and run this to migrate the data:

/*
INSERT INTO test_results (
    pilot_id,
    test_id,
    course_id,
    score,
    passed,
    answers,
    completed_at
)
SELECT 
    pilot_id,
    'a1b2c3d4-e5f6-7890-abcd-000000000001'::uuid as test_id,
    course_id,
    score,
    passed,
    answers,
    completed_at
FROM ground_school_test_results
ON CONFLICT (pilot_id, test_id) DO UPDATE SET
    score = EXCLUDED.score,
    passed = EXCLUDED.passed,
    answers = EXCLUDED.answers,
    completed_at = EXCLUDED.completed_at;

-- Then you can drop the old table:
-- DROP TABLE IF EXISTS ground_school_test_results CASCADE;
*/

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- 1. Verify course_tests table was created
SELECT 'course_tests table created' as status, COUNT(*) as test_count
FROM course_tests;

-- 2. Verify Ground School Test was inserted
SELECT 
    id,
    test_name,
    course_id,
    passing_score,
    required_for_progression,
    required_units
FROM course_tests
WHERE id = 'a1b2c3d4-e5f6-7890-abcd-000000000001'::uuid;

-- 3. Verify test_results table was created
SELECT 'test_results table created' as status;

-- 4. Check RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd
FROM pg_policies
WHERE tablename IN ('course_tests', 'test_results')
ORDER BY tablename, policyname;

-- ============================================================================
-- HELPER QUERIES for development
-- ============================================================================

-- Get all tests for a specific course
-- SELECT * FROM course_tests WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- Get test results for a specific pilot
-- SELECT * FROM test_results WHERE pilot_id = 'YOUR_PILOT_ID';

-- Get test status for a pilot and course
-- SELECT 
--     tr.score,
--     tr.passed,
--     tr.completed_at,
--     ct.test_name
-- FROM test_results tr
-- JOIN course_tests ct ON tr.test_id = ct.id
-- WHERE tr.pilot_id = 'YOUR_PILOT_ID'
--   AND tr.course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

