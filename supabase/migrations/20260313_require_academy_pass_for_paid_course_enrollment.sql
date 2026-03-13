-- Migration: Require Academy Pass before enrolling in paid Buzz Academy courses
-- Description:
--   1. Derives the subscription-exempt academy catalog from backend course metadata
--   2. Checks for an active Academy Pass subscription
--   3. Enforces the requirement in the course_enrollments trigger

CREATE OR REPLACE FUNCTION public.course_is_subscription_exempt_from_enrollment(p_course_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    course_provider text;
    course_title text;
    course_external_url text;
    normalized_course_title text;
    has_unlocked_exam_section boolean := false;
BEGIN
    SELECT
        provider,
        title,
        external_url
    INTO
        course_provider,
        course_title,
        course_external_url
    FROM public.training_courses
    WHERE id = p_course_id;

    IF course_title IS NULL THEN
        RETURN false;
    END IF;

    IF COALESCE(course_external_url, '') <> '' THEN
        RETURN true;
    END IF;

    IF COALESCE(course_provider, '') <> 'Buzz' THEN
        RETURN true;
    END IF;

    normalized_course_title := regexp_replace(
        replace(replace(lower(course_title), '-', ' '), '_', ' '),
        '\s+',
        ' ',
        'g'
    );

    IF normalized_course_title IN ('uas pilot', 'rpas pilot', 'roc a') THEN
        RETURN true;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.course_sections cs
        WHERE cs.course_id = p_course_id
          AND cs.is_active = true
          AND cs.deleted_at IS NULL
          AND COALESCE(cs.requires_subscription, false) = false
          AND (
              regexp_replace(
                  replace(replace(lower(COALESCE(cs.exam_type, '')), '-', ' '), '_', ' '),
                  '\s+',
                  ' ',
                  'g'
              ) IN ('flight review', 'roc a')
              OR regexp_replace(
                  replace(replace(lower(cs.name), '-', ' '), '_', ' '),
                  '\s+',
                  ' ',
                  'g'
              ) LIKE '%flight review%'
              OR regexp_replace(
                  replace(replace(lower(cs.name), '-', ' '), '_', ' '),
                  '\s+',
                  ' ',
                  'g'
              ) LIKE '%roc a%'
          )
    ) INTO has_unlocked_exam_section;

    RETURN has_unlocked_exam_section;
END;
$$;

CREATE OR REPLACE FUNCTION public.pilot_has_active_academy_pass(p_pilot_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.course_subscriptions cs
        WHERE cs.pilot_id = p_pilot_id
          AND cs.status IN ('active', 'trialing')
          AND (cs.current_period_end IS NULL OR cs.current_period_end > timezone('utc'::text, now()))
    );
$$;

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

    IF requires_ground_school = true THEN
        has_passed_gs := public.has_passed_ground_school_test(NEW.pilot_id);

        IF NOT has_passed_gs THEN
            RAISE EXCEPTION 'You must pass the UAS Pilot Ground School Test before enrolling in this course.';
        END IF;
    END IF;

    IF requires_flight_review = true THEN
        has_passed_fr := public.has_passed_flight_review(NEW.pilot_id);

        IF NOT has_passed_fr THEN
            RAISE EXCEPTION 'You must pass the Flight Review exam before enrolling in this course.';
        END IF;
    END IF;

    IF requires_roc_a = true THEN
        has_passed_ra := public.has_passed_roc_a(NEW.pilot_id);

        IF NOT has_passed_ra THEN
            RAISE EXCEPTION 'You must pass the ROC-A exam before enrolling in this course.';
        END IF;
    END IF;

    IF NOT public.course_is_subscription_exempt_from_enrollment(NEW.course_id)
       AND NOT public.pilot_has_active_academy_pass(NEW.pilot_id) THEN
        RAISE EXCEPTION 'An active Buzz Academy Pass subscription is required before enrolling in this course.';
    END IF;

    RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.course_is_subscription_exempt_from_enrollment(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pilot_has_active_academy_pass(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_course_enrollment_prerequisites() TO authenticated;
