-- Migration: Add prerequisite check for course enrollments
-- Prevents enrollment in courses requiring UAS Pilot Ground School Test
-- unless the pilot has passed the test

-- ============================================================
-- Create function to check if pilot has passed ground school test
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_passed_ground_school_test(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    uas_pilot_course_id uuid := 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    ground_school_test_section_id uuid := '00000002-0000-0000-0000-000000000002';
    has_passed boolean;
BEGIN
    -- Check if pilot has completed any unit in the ground school test section
    SELECT EXISTS (
        SELECT 1
        FROM public.unit_completions uc
        INNER JOIN public.course_units cu ON uc.unit_id = cu.id
        WHERE uc.pilot_id = p_pilot_id
          AND cu.course_id = uas_pilot_course_id
          AND cu.section_id = ground_school_test_section_id
          AND uc.completed_at IS NOT NULL
    ) INTO has_passed;
    
    RETURN has_passed;
END;
$$;

-- ============================================================
-- Create trigger function to validate course enrollment prerequisites
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
-- Create trigger on course_enrollments table
-- ============================================================

DROP TRIGGER IF EXISTS check_course_prerequisites ON public.course_enrollments;

CREATE TRIGGER check_course_prerequisites
    BEFORE INSERT ON public.course_enrollments
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_course_enrollment_prerequisites();

-- ============================================================
-- Grant necessary permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.has_passed_ground_school_test(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_course_enrollment_prerequisites() TO authenticated;

-- ============================================================
-- Summary:
-- ============================================================
-- Created function: has_passed_ground_school_test(pilot_id)
--   - Checks unit_completions table for completed units in Ground School Test Section
--   - Ground School Test Section ID: 00000002-0000-0000-0000-000000000002
--   - UAS Pilot Course ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
--
-- Created trigger function: validate_course_enrollment_prerequisites()
--   - Validates that courses requiring ground school test can only be enrolled
--     if the pilot has passed the test
--
-- Created trigger: check_course_prerequisites on course_enrollments
--   - Executes BEFORE INSERT to prevent unauthorized enrollments
--
-- The trigger will automatically prevent enrollments in courses that
-- require the UAS Pilot Ground School Test unless the pilot has passed it.
