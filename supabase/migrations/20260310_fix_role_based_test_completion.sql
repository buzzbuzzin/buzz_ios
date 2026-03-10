-- Migration: Fix role-based test completion for Flight Reviewer and ROC-A Examiner
-- Created: 2026-03-10
-- Description:
--   1. Replace hardcoded prerequisite RPC checks with live test/course matching
--   2. Replace the overly broad auto-complete helper with a role-aware sync
--   3. Keep role-based test completion in sync from pilot_special_roles changes
--   4. Backfill missing role flags/test results and remove corrupted auto-completed rows

-- ============================================================
-- Step 1: Fix prerequisite RPCs to use live test/course matching
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_passed_flight_review(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_pilot_region text;
    has_passed boolean;
BEGIN
    SELECT selected_region
    INTO v_pilot_region
    FROM public.profiles
    WHERE id = p_pilot_id;

    SELECT EXISTS (
        SELECT 1
        FROM public.test_results tr
        JOIN public.course_tests ct ON ct.id = tr.test_id
        JOIN public.training_courses tc ON tc.id = tr.course_id
        WHERE tr.pilot_id = p_pilot_id
          AND tr.passed = true
          AND COALESCE(tr.upload_status, 'approved') = 'approved'
          AND tc.region = v_pilot_region
          AND tc.active = true
          AND tc.deleted_at IS NULL
          AND ct.is_active = true
          AND ct.deleted_at IS NULL
          AND tc.title IN ('RPAS Pilot', 'UAS Pilot')
          AND lower(ct.test_name) LIKE '%flight review practical exam%'
        UNION ALL
        SELECT 1
        FROM public.badges
        WHERE pilot_id = p_pilot_id
          AND badge_type = 'flight_reviewer'
    ) INTO has_passed;

    RETURN COALESCE(has_passed, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.has_passed_roc_a(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_pilot_region text;
    has_passed boolean;
BEGIN
    SELECT selected_region
    INTO v_pilot_region
    FROM public.profiles
    WHERE id = p_pilot_id;

    SELECT EXISTS (
        SELECT 1
        FROM public.test_results tr
        JOIN public.course_tests ct ON ct.id = tr.test_id
        JOIN public.training_courses tc ON tc.id = tr.course_id
        WHERE tr.pilot_id = p_pilot_id
          AND tr.passed = true
          AND COALESCE(tr.upload_status, 'approved') = 'approved'
          AND tc.region = v_pilot_region
          AND tc.active = true
          AND tc.deleted_at IS NULL
          AND ct.is_active = true
          AND ct.deleted_at IS NULL
          AND tc.title = 'ROC-A'
          AND (
            lower(ct.test_name) LIKE '%roc-a radio competency exam%'
            OR lower(ct.test_name) LIKE '%roc a radio competency exam%'
            OR lower(ct.test_name) LIKE '%roc-a%'
            OR lower(ct.test_name) LIKE '%roc a%'
          )
        UNION ALL
        SELECT 1
        FROM public.badges
        WHERE pilot_id = p_pilot_id
          AND badge_type = 'roc_a_examiner'
    ) INTO has_passed;

    RETURN COALESCE(has_passed, false);
END;
$$;

-- ============================================================
-- Step 2: Create a precise role-based sync helper
-- ============================================================

CREATE OR REPLACE FUNCTION public.sync_role_based_test_completion(
    p_pilot_id uuid,
    p_role_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_pilot_region text;
    v_rec record;
    v_attempt_number integer;
    v_synced_tests integer := 0;
BEGIN
    -- Allow service role/trigger execution (auth.uid() is null there),
    -- otherwise require an admin/owner profile.
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid()
          AND (
            user_type IN ('admin', 'owner')
            OR role IN ('admin', 'owner')
          )
    ) THEN
        RAISE EXCEPTION 'Unauthorized: caller is not an admin or owner';
    END IF;

    IF p_role_type NOT IN ('flight_reviewer', 'roc_a_examiner') THEN
        RETURN jsonb_build_object(
            'error', 'Invalid role_type. Must be flight_reviewer or roc_a_examiner.',
            'synced_tests', 0
        );
    END IF;

    SELECT selected_region
    INTO v_pilot_region
    FROM public.profiles
    WHERE id = p_pilot_id;

    IF COALESCE(v_pilot_region, '') = '' OR v_pilot_region = 'Other' THEN
        RETURN jsonb_build_object(
            'pilot_id', p_pilot_id,
            'role_type', p_role_type,
            'synced_tests', 0,
            'skipped', true,
            'reason', 'Pilot has no valid selected_region'
        );
    END IF;

    FOR v_rec IN
        SELECT DISTINCT
            ct.id AS test_id,
            ct.course_id
        FROM public.course_tests ct
        JOIN public.training_courses tc ON tc.id = ct.course_id
        WHERE tc.region = v_pilot_region
          AND tc.active = true
          AND tc.deleted_at IS NULL
          AND ct.is_active = true
          AND ct.deleted_at IS NULL
          AND (
            (
                p_role_type = 'flight_reviewer'
                AND tc.title IN ('RPAS Pilot', 'UAS Pilot')
                AND lower(ct.test_name) LIKE '%flight review practical exam%'
            )
            OR
            (
                p_role_type = 'roc_a_examiner'
                AND tc.title = 'ROC-A'
                AND (
                    lower(ct.test_name) LIKE '%roc-a radio competency exam%'
                    OR lower(ct.test_name) LIKE '%roc a radio competency exam%'
                    OR lower(ct.test_name) LIKE '%roc-a%'
                    OR lower(ct.test_name) LIKE '%roc a%'
                )
            )
          )
    LOOP
        -- Ensure the pilot is enrolled so Test Center can render the test.
        INSERT INTO public.course_enrollments (
            id,
            pilot_id,
            course_id,
            enrolled_at,
            completed_at,
            progress_percentage
        ) VALUES (
            gen_random_uuid(),
            p_pilot_id,
            v_rec.course_id,
            NOW(),
            NULL,
            0
        )
        ON CONFLICT (pilot_id, course_id) DO NOTHING;

        SELECT COALESCE(MAX(attempt_number), 0) + 1
        INTO v_attempt_number
        FROM public.test_results
        WHERE pilot_id = p_pilot_id
          AND test_id = v_rec.test_id;

        INSERT INTO public.test_results (
            id,
            pilot_id,
            test_id,
            course_id,
            score,
            passed,
            answers,
            attempt_number,
            completed_at,
            result_file_urls,
            upload_status,
            reviewer_notes,
            uploaded_at,
            reviewed_at,
            reviewed_by,
            proctor_name
        ) VALUES (
            gen_random_uuid(),
            p_pilot_id,
            v_rec.test_id,
            v_rec.course_id,
            100,
            true,
            NULL,
            v_attempt_number,
            NOW(),
            ARRAY[]::text[],
            'approved',
            'Auto-completed: pilot has ' || p_role_type || ' badge',
            NULL,
            NULL,
            NULL,
            NULL
        )
        ON CONFLICT (pilot_id, test_id) DO UPDATE
        SET
            course_id = EXCLUDED.course_id,
            score = CASE
                WHEN public.test_results.passed = true THEN public.test_results.score
                ELSE 100
            END,
            passed = true,
            upload_status = CASE
                WHEN public.test_results.upload_status = 'approved' THEN public.test_results.upload_status
                ELSE 'approved'
            END,
            reviewer_notes = CASE
                WHEN public.test_results.reviewer_notes IS NULL
                  OR public.test_results.reviewer_notes LIKE 'Auto-completed:%'
                THEN EXCLUDED.reviewer_notes
                ELSE public.test_results.reviewer_notes
            END,
            completed_at = COALESCE(public.test_results.completed_at, EXCLUDED.completed_at),
            result_file_urls = COALESCE(public.test_results.result_file_urls, EXCLUDED.result_file_urls)
        WHERE public.test_results.passed IS DISTINCT FROM true
           OR public.test_results.upload_status IS DISTINCT FROM 'approved'
           OR public.test_results.reviewer_notes IS NULL
           OR public.test_results.reviewer_notes LIKE 'Auto-completed:%';

        v_synced_tests := v_synced_tests + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'pilot_id', p_pilot_id,
        'role_type', p_role_type,
        'pilot_region', v_pilot_region,
        'synced_tests', v_synced_tests
    );
END;
$$;

COMMENT ON FUNCTION public.sync_role_based_test_completion(uuid, text) IS
'Ensures Flight Reviewer and ROC-A Examiner special roles create the correct enrolled-course test_results rows for the pilot''s selected region.';

-- ============================================================
-- Step 3: Replace the drifted admin utility wrappers
-- ============================================================

CREATE OR REPLACE FUNCTION public.auto_complete_tests_for_role(
    p_pilot_id uuid,
    p_role_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    RETURN public.sync_role_based_test_completion(p_pilot_id, p_role_type);
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_auto_completed_tests_for_role(
    p_pilot_id uuid,
    p_role_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_deleted_count int;
    v_other_role text;
    v_has_other_role boolean;
    v_backfill_result jsonb;
    v_backfill_count int := 0;
BEGIN
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid()
          AND (
            user_type IN ('admin', 'owner')
            OR role IN ('admin', 'owner')
          )
    ) THEN
        RAISE EXCEPTION 'Unauthorized: caller is not an admin or owner';
    END IF;

    IF p_role_type NOT IN ('flight_reviewer', 'roc_a_examiner') THEN
        RETURN jsonb_build_object(
            'error', 'Invalid role_type. Must be flight_reviewer or roc_a_examiner.',
            'revoked_tests', 0
        );
    END IF;

    DELETE FROM public.test_results
    WHERE pilot_id = p_pilot_id
      AND reviewer_notes = 'Auto-completed: pilot has ' || p_role_type || ' badge';

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    v_other_role := CASE
        WHEN p_role_type = 'flight_reviewer' THEN 'roc_a_examiner'
        ELSE 'flight_reviewer'
    END;

    SELECT CASE
        WHEN v_other_role = 'flight_reviewer' THEN COALESCE(flight_reviewer, false)
        ELSE COALESCE(roc_a_examiner, false)
    END
    INTO v_has_other_role
    FROM public.pilot_special_roles
    WHERE pilot_id = p_pilot_id;

    IF v_has_other_role = true THEN
        v_backfill_result := public.sync_role_based_test_completion(p_pilot_id, v_other_role);
        v_backfill_count := COALESCE((v_backfill_result ->> 'synced_tests')::int, 0);
    END IF;

    RETURN jsonb_build_object(
        'pilot_id', p_pilot_id,
        'role_type', p_role_type,
        'revoked_tests', v_deleted_count,
        'backfilled_for_other_role', v_backfill_count
    );
END;
$$;

-- ============================================================
-- Step 4: Sync tests automatically from pilot_special_roles
-- ============================================================

CREATE OR REPLACE FUNCTION public.sync_test_completion_for_special_roles()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF COALESCE(NEW.flight_reviewer, false) THEN
            PERFORM public.sync_role_based_test_completion(NEW.pilot_id, 'flight_reviewer');
        END IF;

        IF COALESCE(NEW.roc_a_examiner, false) THEN
            PERFORM public.sync_role_based_test_completion(NEW.pilot_id, 'roc_a_examiner');
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF COALESCE(NEW.flight_reviewer, false) = true AND COALESCE(OLD.flight_reviewer, false) = false THEN
            PERFORM public.sync_role_based_test_completion(NEW.pilot_id, 'flight_reviewer');
        ELSIF COALESCE(OLD.flight_reviewer, false) = true AND COALESCE(NEW.flight_reviewer, false) = false THEN
            PERFORM public.revoke_auto_completed_tests_for_role(NEW.pilot_id, 'flight_reviewer');
        END IF;

        IF COALESCE(NEW.roc_a_examiner, false) = true AND COALESCE(OLD.roc_a_examiner, false) = false THEN
            PERFORM public.sync_role_based_test_completion(NEW.pilot_id, 'roc_a_examiner');
        ELSIF COALESCE(OLD.roc_a_examiner, false) = true AND COALESCE(NEW.roc_a_examiner, false) = false THEN
            PERFORM public.revoke_auto_completed_tests_for_role(NEW.pilot_id, 'roc_a_examiner');
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_sync_test_completion_for_special_roles ON public.pilot_special_roles;

CREATE TRIGGER trigger_sync_test_completion_for_special_roles
AFTER INSERT OR UPDATE ON public.pilot_special_roles
FOR EACH ROW
EXECUTE FUNCTION public.sync_test_completion_for_special_roles();

-- ============================================================
-- Step 5: Remove corrupted auto-completed rows from the old helper
-- ============================================================

DELETE FROM public.test_results tr
USING public.course_tests ct
WHERE tr.test_id = ct.id
  AND tr.reviewer_notes = 'Auto-completed: pilot has flight_reviewer badge'
  AND lower(ct.test_name) NOT LIKE '%flight review%';

DELETE FROM public.test_results tr
USING public.course_tests ct
WHERE tr.test_id = ct.id
  AND tr.reviewer_notes = 'Auto-completed: pilot has roc_a_examiner badge'
  AND lower(ct.test_name) NOT LIKE '%roc-a%'
  AND lower(ct.test_name) NOT LIKE '%roc a%';

-- ============================================================
-- Step 6: Repair role drift from existing badges
-- ============================================================

INSERT INTO public.pilot_special_roles (
    pilot_id,
    flight_reviewer,
    roc_a_examiner
)
SELECT
    b.pilot_id,
    BOOL_OR(b.badge_type = 'flight_reviewer') AS flight_reviewer,
    BOOL_OR(b.badge_type = 'roc_a_examiner') AS roc_a_examiner
FROM public.badges b
WHERE b.badge_type IN ('flight_reviewer', 'roc_a_examiner')
GROUP BY b.pilot_id
ON CONFLICT (pilot_id) DO UPDATE
SET
    flight_reviewer = public.pilot_special_roles.flight_reviewer OR EXCLUDED.flight_reviewer,
    roc_a_examiner = public.pilot_special_roles.roc_a_examiner OR EXCLUDED.roc_a_examiner;

-- ============================================================
-- Step 7: Backfill all currently badged pilots with the correct test rows
-- ============================================================

DO $$
DECLARE
    v_rec record;
BEGIN
    FOR v_rec IN
        SELECT pilot_id, 'flight_reviewer'::text AS role_type
        FROM public.pilot_special_roles
        WHERE COALESCE(flight_reviewer, false) = true
        UNION ALL
        SELECT pilot_id, 'roc_a_examiner'::text AS role_type
        FROM public.pilot_special_roles
        WHERE COALESCE(roc_a_examiner, false) = true
    LOOP
        PERFORM public.sync_role_based_test_completion(v_rec.pilot_id, v_rec.role_type);
    END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.has_passed_flight_review(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_passed_roc_a(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_role_based_test_completion(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_complete_tests_for_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_auto_completed_tests_for_role(uuid, text) TO authenticated;
