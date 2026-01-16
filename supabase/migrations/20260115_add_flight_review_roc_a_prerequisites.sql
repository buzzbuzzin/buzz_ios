-- Migration: Add Flight Review and ROC-A Prerequisites
-- Description: Adds prerequisites requiring pilots to pass Flight Review and ROC-A tests
--              before enrolling in most courses (except UAS Pilot, Flight Review, and ROC-A)
-- Created: 2026-01-15

-- ============================================================
-- Step 1: Add new prerequisite columns to training_courses
-- ============================================================

-- Add requires_flight_review_passed column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'training_courses' 
        AND column_name = 'requires_flight_review_passed'
    ) THEN
        ALTER TABLE public.training_courses 
        ADD COLUMN requires_flight_review_passed boolean DEFAULT false;
        RAISE NOTICE 'Added requires_flight_review_passed column';
    ELSE
        RAISE NOTICE 'Column requires_flight_review_passed already exists';
    END IF;
END $$;

-- Add requires_roc_a_passed column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'training_courses' 
        AND column_name = 'requires_roc_a_passed'
    ) THEN
        ALTER TABLE public.training_courses 
        ADD COLUMN requires_roc_a_passed boolean DEFAULT false;
        RAISE NOTICE 'Added requires_roc_a_passed column';
    ELSE
        RAISE NOTICE 'Column requires_roc_a_passed already exists';
    END IF;
END $$;

-- ============================================================
-- Step 2: Create course_tests entries for Flight Review and ROC-A
-- These are required because test_results.test_id references course_tests
-- ============================================================

-- Flight Review Practical Exam
INSERT INTO public.course_tests (
    id,
    course_id,
    test_name,
    test_description,
    test_type,
    passing_score,
    required_for_progression,
    order_index,
    is_active
)
VALUES (
    'f1a2b3c4-d5e6-7890-abcd-f11ab0000001',
    'b2c3d4e5-f6a7-8901-bcde-f23456789012',  -- Flight Review course
    'Flight Review Practical Exam',
    'In-person practical flight assessment conducted by a certified Flight Reviewer. Evaluates pre-flight procedures, flight execution, and post-flight protocols.',
    'practical',
    70,
    true,
    1,
    true
)
ON CONFLICT (id) DO NOTHING;

-- ROC-A Radio Competency Exam
INSERT INTO public.course_tests (
    id,
    course_id,
    test_name,
    test_description,
    test_type,
    passing_score,
    required_for_progression,
    order_index,
    is_active
)
VALUES (
    'a0c4a5b6-c7d8-9012-efab-a0ca00000001',
    'c3d4e5f6-a7b8-9012-cdef-345678901234',  -- ROC-A course
    'ROC-A Radio Competency Exam',
    'Radio communication competency certification exam. Demonstrates competence in operating aeronautical radio equipment and proper radiotelephone communication procedures.',
    'oral',
    70,
    true,
    1,
    true
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Step 3: Create helper function to check if pilot passed Flight Review
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_passed_flight_review(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    flight_review_course_id uuid := 'b2c3d4e5-f6a7-8901-bcde-f23456789012';
    has_passed boolean;
BEGIN
    -- Check if pilot has passed the Flight Review test
    SELECT EXISTS (
        SELECT 1
        FROM public.test_results
        WHERE pilot_id = p_pilot_id
          AND course_id = flight_review_course_id
          AND passed = true
    ) INTO has_passed;
    
    RAISE LOG 'Flight Review Check - Pilot: %, Has passed: %', p_pilot_id, has_passed;
    
    RETURN COALESCE(has_passed, false);
END;
$$;

-- ============================================================
-- Step 4: Create helper function to check if pilot passed ROC-A
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_passed_roc_a(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    roc_a_course_id uuid := 'c3d4e5f6-a7b8-9012-cdef-345678901234';
    has_passed boolean;
BEGIN
    -- Check if pilot has passed the ROC-A test
    SELECT EXISTS (
        SELECT 1
        FROM public.test_results
        WHERE pilot_id = p_pilot_id
          AND course_id = roc_a_course_id
          AND passed = true
    ) INTO has_passed;
    
    RAISE LOG 'ROC-A Check - Pilot: %, Has passed: %', p_pilot_id, has_passed;
    
    RETURN COALESCE(has_passed, false);
END;
$$;

-- ============================================================
-- Step 5: Update the prerequisite validation trigger function
-- Now checks all three prerequisites: Ground School, Flight Review, ROC-A
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_course_enrollment_prerequisites()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    requires_ground_school boolean;
    requires_flight_review boolean;
    requires_roc_a boolean;
    course_title text;
    has_passed_gs boolean;
    has_passed_fr boolean;
    has_passed_ra boolean;
BEGIN
    -- Get course prerequisite requirements
    SELECT 
        COALESCE(requires_uas_ground_school, false),
        COALESCE(requires_flight_review_passed, false),
        COALESCE(requires_roc_a_passed, false),
        title
    INTO requires_ground_school, requires_flight_review, requires_roc_a, course_title
    FROM public.training_courses
    WHERE id = NEW.course_id;
    
    RAISE LOG 'Enrollment attempt - Course: %, Pilot: %, Requires GS: %, Requires FR: %, Requires ROC-A: %', 
        course_title, NEW.pilot_id, requires_ground_school, requires_flight_review, requires_roc_a;
    
    -- Check Ground School prerequisite
    IF requires_ground_school = true THEN
        has_passed_gs := public.has_passed_ground_school_test(NEW.pilot_id);
        
        IF NOT has_passed_gs THEN
            RAISE EXCEPTION 'You must pass the UAS Pilot Ground School Test before enrolling in this course.';
        END IF;
    END IF;
    
    -- Check Flight Review prerequisite
    IF requires_flight_review = true THEN
        has_passed_fr := public.has_passed_flight_review(NEW.pilot_id);
        
        IF NOT has_passed_fr THEN
            RAISE EXCEPTION 'You must pass the Flight Review exam before enrolling in this course.';
        END IF;
    END IF;
    
    -- Check ROC-A prerequisite
    IF requires_roc_a = true THEN
        has_passed_ra := public.has_passed_roc_a(NEW.pilot_id);
        
        IF NOT has_passed_ra THEN
            RAISE EXCEPTION 'You must pass the ROC-A exam before enrolling in this course.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- ============================================================
-- Step 6: Grant necessary permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.has_passed_flight_review(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_passed_roc_a(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_course_enrollment_prerequisites() TO authenticated;

-- ============================================================
-- Step 7: Ensure trigger exists (recreate to use updated function)
-- ============================================================

DROP TRIGGER IF EXISTS check_course_prerequisites ON public.course_enrollments;

CREATE TRIGGER check_course_prerequisites
    BEFORE INSERT ON public.course_enrollments
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_course_enrollment_prerequisites();

-- ============================================================
-- Step 8: Set prerequisites on all courses EXCEPT the three excluded ones
-- Excluded courses:
--   - UAS Pilot (a1b2c3d4-e5f6-7890-abcd-ef1234567890)
--   - Flight Review (b2c3d4e5-f6a7-8901-bcde-f23456789012)
--   - ROC-A (c3d4e5f6-a7b8-9012-cdef-345678901234)
-- ============================================================

UPDATE public.training_courses
SET 
    requires_flight_review_passed = true,
    requires_roc_a_passed = true,
    updated_at = timezone('utc'::text, now())
WHERE id NOT IN (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',  -- UAS Pilot
    'b2c3d4e5-f6a7-8901-bcde-f23456789012',  -- Flight Review
    'c3d4e5f6-a7b8-9012-cdef-345678901234'   -- ROC-A
);

-- ============================================================
-- Summary
-- ============================================================
-- 
-- New columns added to training_courses:
--   - requires_flight_review_passed (boolean, default false)
--   - requires_roc_a_passed (boolean, default false)
--
-- New course_tests entries:
--   - Flight Review Practical Exam (f1a2b3c4-d5e6-7890-abcd-f11ab0000001)
--   - ROC-A Radio Competency Exam (a0c4a5b6-c7d8-9012-efab-a0ca00000001)
--
-- New helper functions:
--   - has_passed_flight_review(uuid) - checks test_results for Flight Review course
--   - has_passed_roc_a(uuid) - checks test_results for ROC-A course
--
-- Updated trigger function:
--   - validate_course_enrollment_prerequisites() now checks all 3 prerequisites
--
-- Courses with prerequisites set to true:
--   - All courses EXCEPT UAS Pilot, Flight Review, and ROC-A
--
-- ============================================================
-- Verification Queries (run manually)
-- ============================================================
--
-- 1. Check new columns exist:
-- SELECT column_name, data_type, column_default 
-- FROM information_schema.columns 
-- WHERE table_name = 'training_courses' 
-- AND column_name IN ('requires_flight_review_passed', 'requires_roc_a_passed');
--
-- 2. Check course_tests entries:
-- SELECT id, course_id, test_name, test_type FROM public.course_tests 
-- WHERE id IN ('f1a2b3c4-d5e6-7890-abcd-f11ab0000001', 'a0c4a5b6-c7d8-9012-efab-a0ca00000001');
--
-- 3. Check courses with prerequisites:
-- SELECT id, title, requires_uas_ground_school, requires_flight_review_passed, requires_roc_a_passed 
-- FROM public.training_courses 
-- ORDER BY title;
--
-- 4. Check helper functions exist:
-- SELECT routine_name FROM information_schema.routines 
-- WHERE routine_schema = 'public' 
-- AND routine_name IN ('has_passed_flight_review', 'has_passed_roc_a');
