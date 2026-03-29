-- Migration: Remove "Become A Flight Reviewer" exemption from Academy Pass requirement
-- This course now requires a Buzz Academy Subscription to enroll.

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

    -- Only UAS Pilot, RPAS Pilot, and ROC A are exempt by title.
    -- "Become A Flight Reviewer" is NOT exempt (requires Buzz Academy Subscription).
    IF normalized_course_title IN ('uas pilot', 'rpas pilot', 'roc a') THEN
        RETURN true;
    END IF;

    -- Flight Reviewer course requires subscription — skip section-level fallback
    IF normalized_course_title LIKE '%flight reviewer%' THEN
        RETURN false;
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

GRANT EXECUTE ON FUNCTION public.course_is_subscription_exempt_from_enrollment(uuid) TO authenticated;
