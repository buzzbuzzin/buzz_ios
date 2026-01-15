-- Migration: Fix Ground School Test prerequisite check
-- Description: Adds better logging and ensures the prerequisite check works correctly
-- Created: 2026-01-15

-- ============================================================
-- Step 1: Recreate the function with better error handling
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_passed_ground_school_test(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    uas_pilot_course_id uuid := 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    has_passed boolean;
    test_count integer;
BEGIN
    -- Count how many test records exist for this pilot and course
    SELECT COUNT(*)
    INTO test_count
    FROM public.test_results
    WHERE pilot_id = p_pilot_id
      AND course_id = uas_pilot_course_id;
    
    -- Log for debugging
    RAISE LOG 'Ground School Test Check - Pilot: %, Test records found: %', p_pilot_id, test_count;
    
    -- Check if pilot has passed the ground school test
    SELECT EXISTS (
        SELECT 1
        FROM public.test_results
        WHERE pilot_id = p_pilot_id
          AND course_id = uas_pilot_course_id
          AND passed = true
    ) INTO has_passed;
    
    RAISE LOG 'Ground School Test Check - Pilot: %, Has passed: %', p_pilot_id, has_passed;
    
    RETURN COALESCE(has_passed, false);
END;
$$;

-- ============================================================
-- Step 2: Update the trigger function with better error messaging
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_course_enrollment_prerequisites()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    requires_test boolean;
    course_title text;
    has_passed boolean;
BEGIN
    -- Get course details
    SELECT requires_uas_ground_school, title
    INTO requires_test, course_title
    FROM public.training_courses
    WHERE id = NEW.course_id;
    
    -- If course requires ground school test, check if pilot has passed
    IF requires_test = true THEN
        has_passed := public.has_passed_ground_school_test(NEW.pilot_id);
        
        RAISE LOG 'Enrollment attempt - Course: %, Pilot: %, Requires test: %, Has passed: %', 
            course_title, NEW.pilot_id, requires_test, has_passed;
        
        IF NOT has_passed THEN
            RAISE EXCEPTION 'You must pass the UAS Pilot Ground School Test before enrolling in this course.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- ============================================================
-- Step 3: Grant necessary permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.has_passed_ground_school_test(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_course_enrollment_prerequisites() TO authenticated;

-- ============================================================
-- Step 4: Ensure trigger exists
-- ============================================================

DROP TRIGGER IF EXISTS check_course_prerequisites ON public.course_enrollments;

CREATE TRIGGER check_course_prerequisites
    BEFORE INSERT ON public.course_enrollments
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_course_enrollment_prerequisites();

-- ============================================================
-- Verification Query
-- ============================================================
-- Run these to verify everything is set up correctly:
-- 
-- 1. Check if function exists:
-- SELECT routine_name, routine_type FROM information_schema.routines 
-- WHERE routine_schema = 'public' AND routine_name LIKE '%ground_school%';
--
-- 2. Check if trigger exists:
-- SELECT trigger_name, event_manipulation, event_object_table 
-- FROM information_schema.triggers 
-- WHERE trigger_name = 'check_course_prerequisites';
