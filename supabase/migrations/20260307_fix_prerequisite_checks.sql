-- Migration: Fix prerequisite checks for badge-based qualifications
-- Description: Updates has_passed_flight_review() and has_passed_roc_a() to recognize
--              pilots who earned badges via license approval (not just test_results).
--              Restores the comprehensive prerequisite trigger that was overwritten.
-- Created: 2026-03-07

-- ============================================================
-- Step 1: Update has_passed_flight_review() to check badges too
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
    -- Check if pilot has EITHER:
    --   1. A test_results entry with passed=true for the Flight Review course
    --   2. A flight_reviewer badge in the badges table
    SELECT EXISTS (
        SELECT 1
        FROM public.test_results
        WHERE pilot_id = p_pilot_id
          AND course_id = flight_review_course_id
          AND passed = true
        UNION ALL
        SELECT 1
        FROM public.badges
        WHERE pilot_id = p_pilot_id
          AND badge_type = 'flight_reviewer'
    ) INTO has_passed;

    RAISE LOG 'Flight Review Check - Pilot: %, Has passed: %', p_pilot_id, has_passed;

    RETURN COALESCE(has_passed, false);
END;
$$;

-- ============================================================
-- Step 2: Update has_passed_roc_a() to check badges too
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
    -- Check if pilot has EITHER:
    --   1. A test_results entry with passed=true for the ROC-A course
    --   2. A roc_a_examiner badge in the badges table
    SELECT EXISTS (
        SELECT 1
        FROM public.test_results
        WHERE pilot_id = p_pilot_id
          AND course_id = roc_a_course_id
          AND passed = true
        UNION ALL
        SELECT 1
        FROM public.badges
        WHERE pilot_id = p_pilot_id
          AND badge_type = 'roc_a_examiner'
    ) INTO has_passed;

    RAISE LOG 'ROC-A Check - Pilot: %, Has passed: %', p_pilot_id, has_passed;

    RETURN COALESCE(has_passed, false);
END;
$$;

-- ============================================================
-- Step 3: Restore comprehensive validate_course_enrollment_prerequisites()
-- The 20260115_fix_ground_school_prerequisite_check.sql migration
-- overwrote this to only check ground school. Restore all 3 checks.
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
-- Step 4: Safety guard - prevent circular prerequisites
-- Ensure Flight Review, ROC-A, and UAS Pilot courses don't
-- require flight review or ROC-A (which would lock them forever)
-- ============================================================

UPDATE public.training_courses
SET
    requires_flight_review_passed = false,
    requires_roc_a_passed = false,
    updated_at = timezone('utc'::text, now())
WHERE id IN (
    'b2c3d4e5-f6a7-8901-bcde-f23456789012',  -- Flight Review
    'c3d4e5f6-a7b8-9012-cdef-345678901234',  -- ROC-A
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'   -- UAS Pilot
);

-- ============================================================
-- Step 5: Grant permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.has_passed_flight_review(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_passed_roc_a(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_course_enrollment_prerequisites() TO authenticated;

-- ============================================================
-- Verification Queries (run manually)
-- ============================================================
--
-- 1. Test that badge holders are recognized:
-- SELECT has_passed_flight_review('<pilot_uuid>');
-- Should return true for pilots with flight_reviewer badge
--
-- 2. Verify no circular prerequisites:
-- SELECT id, title, requires_flight_review_passed, requires_roc_a_passed
-- FROM training_courses
-- WHERE id IN ('b2c3d4e5-f6a7-8901-bcde-f23456789012', 'c3d4e5f6-a7b8-9012-cdef-345678901234');
-- Both should show false
--
-- 3. Check trigger function is comprehensive:
-- SELECT prosrc FROM pg_proc WHERE proname = 'validate_course_enrollment_prerequisites';
-- Should contain references to all three prerequisite checks
