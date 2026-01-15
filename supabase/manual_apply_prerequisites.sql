-- Standalone script to manually apply the course prerequisite changes
-- Run this directly in your Supabase SQL Editor if migrations are not working

-- ============================================================
-- Part 1: Add requires_uas_ground_school column
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'training_courses' 
        AND column_name = 'requires_uas_ground_school'
    ) THEN
        ALTER TABLE public.training_courses 
        ADD COLUMN requires_uas_ground_school boolean DEFAULT false;
        RAISE NOTICE 'Added requires_uas_ground_school column';
    ELSE
        RAISE NOTICE 'Column requires_uas_ground_school already exists';
    END IF;
END $$;

-- ============================================================
-- Part 2: Update existing courses to require ground school test
-- ============================================================

-- Flight Review
UPDATE public.training_courses
SET requires_uas_ground_school = true
WHERE id = 'b2c3d4e5-f6a7-8901-bcde-f23456789012';

-- ROC-A Exam
UPDATE public.training_courses
SET requires_uas_ground_school = true
WHERE id = 'c3d4e5f6-a7b8-9012-cdef-345678901234';

-- FAA 107 Recurrent Training
UPDATE public.training_courses
SET requires_uas_ground_school = true
WHERE id = 'd4e5f6a7-b8c9-0123-defa-456789012345';

-- Extension Courses
UPDATE public.training_courses
SET requires_uas_ground_school = true
WHERE id = 'e5f6a7b8-c9d0-1234-efab-567890123456';

-- ============================================================
-- Part 3: Create prerequisite check function
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_passed_ground_school_test(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    uas_pilot_course_id uuid := 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    has_passed boolean;
BEGIN
    -- Check if pilot has passed the ground school test in test_results table
    SELECT EXISTS (
        SELECT 1
        FROM public.test_results
        WHERE pilot_id = p_pilot_id
          AND course_id = uas_pilot_course_id
          AND passed = true
    ) INTO has_passed;
    
    RETURN has_passed;
END;
$$;

-- ============================================================
-- Part 4: Create trigger function
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_course_enrollment_prerequisites()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    requires_test boolean;
BEGIN
    -- Check if the course requires ground school test
    SELECT requires_uas_ground_school
    INTO requires_test
    FROM public.training_courses
    WHERE id = NEW.course_id;
    
    -- If course requires ground school test, check if pilot has passed
    IF requires_test = true THEN
        IF NOT public.has_passed_ground_school_test(NEW.pilot_id) THEN
            RAISE EXCEPTION 'You must pass the UAS Pilot Ground School Test before enrolling in this course.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- ============================================================
-- Part 5: Create trigger
-- ============================================================

DROP TRIGGER IF EXISTS check_course_prerequisites ON public.course_enrollments;

CREATE TRIGGER check_course_prerequisites
    BEFORE INSERT ON public.course_enrollments
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_course_enrollment_prerequisites();

-- ============================================================
-- Part 6: Grant permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.has_passed_ground_school_test(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_course_enrollment_prerequisites() TO authenticated;

-- ============================================================
-- Verification queries
-- ============================================================

-- Check if column was added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'training_courses' AND column_name = 'requires_uas_ground_school';

-- Check which courses require ground school test
SELECT id, title, requires_uas_ground_school
FROM public.training_courses
WHERE requires_uas_ground_school = true;

-- Check if functions exist
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('has_passed_ground_school_test', 'validate_course_enrollment_prerequisites');

-- Check if trigger exists
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'check_course_prerequisites';
