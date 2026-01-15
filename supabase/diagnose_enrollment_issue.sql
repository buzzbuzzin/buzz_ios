-- Comprehensive diagnostic for Ground School Test enrollment issue
-- This script helps diagnose why a pilot can't enroll despite passing the test

-- ============================================================
-- Step 1: Find your pilot_id from auth.users
-- ============================================================
-- Run this first to get your pilot_id
-- SELECT id, email FROM auth.users WHERE email = 'YOUR_EMAIL_HERE';

-- ============================================================
-- Step 2: Check if you have a passing test result
-- ============================================================
-- Replace <PILOT_ID> with the UUID from Step 1
/*
SELECT 
    tr.pilot_id,
    tr.course_id,
    tc.title AS course_title,
    tr.score,
    tr.passed,
    tr.created_at,
    tr.updated_at
FROM public.test_results tr
LEFT JOIN public.training_courses tc ON tr.course_id = tc.id
WHERE tr.pilot_id = '<PILOT_ID>'
ORDER BY tr.created_at DESC;
*/

-- ============================================================
-- Step 3: Test the prerequisite function directly
-- ============================================================
-- Replace <PILOT_ID> with your actual pilot ID
/*
SELECT public.has_passed_ground_school_test('<PILOT_ID>') AS has_passed;
*/

-- ============================================================
-- Step 4: Check Extension Courses prerequisites
-- ============================================================
SELECT 
    id,
    title,
    requires_uas_ground_school,
    provider
FROM public.training_courses
WHERE title LIKE '%Extension%'
   OR id = 'e5f6a7b8-c9d0-1234-efab-567890123456';

-- ============================================================
-- Step 5: Check your existing enrollments
-- ============================================================
-- Replace <PILOT_ID> with your actual pilot ID
/*
SELECT 
    ce.pilot_id,
    ce.course_id,
    tc.title AS course_title,
    ce.enrolled_at
FROM public.course_enrollments ce
LEFT JOIN public.training_courses tc ON ce.course_id = tc.id
WHERE ce.pilot_id = '<PILOT_ID>'
ORDER BY ce.enrolled_at DESC;
*/

-- ============================================================
-- QUICK FIX: Manually verify the function works
-- ============================================================
-- This recreates the function to ensure it's correct
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
    
    -- Debug logging
    RAISE NOTICE 'Checking pilot %, has_passed: %', p_pilot_id, has_passed;
    
    RETURN has_passed;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.has_passed_ground_school_test(uuid) TO authenticated;

-- ============================================================
-- ALTERNATIVE FIX: Temporarily disable the prerequisite check
-- (Only use this for testing/debugging!)
-- ============================================================
/*
-- Disable the trigger temporarily
ALTER TABLE public.course_enrollments DISABLE TRIGGER check_course_prerequisites;

-- To re-enable later:
-- ALTER TABLE public.course_enrollments ENABLE TRIGGER check_course_prerequisites;
*/
