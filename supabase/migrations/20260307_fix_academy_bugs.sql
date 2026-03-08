-- ============================================================
-- Migration: Fix Academy Bugs
-- Date: 2026-03-07
-- Description: Fixes several database-level issues:
--   C6 — Add missing unique constraint on test_results(pilot_id, test_id)
--        for upsert support in submit_test_result_upload.
--   C9 — Fix ROC-A license type string mismatch in
--        award_permit_badge_for_license_approval trigger.
--   H4 — Add admin guard to approve_test_result and reject_test_result
--        functions so only administrators can call them.
--   M5 — Fix beacon badge duplicate protection in
--        award_beacon_training_badge by replacing ON CONFLICT DO NOTHING
--        (which doesn't work with random UUIDs) with IF NOT EXISTS.
--   M6 — Add verified check to check_beacon_training_complete so only
--        verified training records count toward completion.
--   M7 — Add auth.uid() ownership check to submit_test_result_upload
--        to prevent pilots from submitting results for others.
-- ============================================================


-- ============================================================
-- C6 — Missing unique constraint on test_results
-- ============================================================

-- Deduplicate test_results before adding unique constraint.
-- Keeps the best result: passed=true preferred, then latest created_at.
DELETE FROM public.test_results a
USING public.test_results b
WHERE a.pilot_id = b.pilot_id
  AND a.test_id = b.test_id
  AND a.id != b.id
  AND (
    (a.passed = false AND b.passed = true) OR
    (a.passed = b.passed AND a.created_at < b.created_at)
  );

-- Add unique constraint for upsert support (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'test_results_pilot_id_test_id_key'
    ) THEN
        ALTER TABLE public.test_results ADD CONSTRAINT test_results_pilot_id_test_id_key UNIQUE (pilot_id, test_id);
    END IF;
END $$;


-- ============================================================
-- C9 — ROC-A license type string mismatch
-- ============================================================

-- The trigger previously only matched 'ROC-A Examiner (CAN)' but the iOS
-- app may send 'ROC-A (CAN)' or 'ROC-A Certificate (CAN)' as well.
-- Update to accept all known ROC-A license type strings.
CREATE OR REPLACE FUNCTION public.award_permit_badge_for_license_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_badge_type TEXT;
BEGIN
  -- Determine which badge to award based on license type
  IF NEW.license_type = 'Flight Reviewer (CAN)' THEN
    target_badge_type := 'flight_reviewer';
  ELSIF NEW.license_type IN ('ROC-A (CAN)', 'ROC-A Certificate (CAN)', 'ROC-A Examiner (CAN)') THEN
    target_badge_type := 'roc_a_examiner';
  ELSE
    RETURN NEW;
  END IF;

  -- On INSERT: skip badge award (requests start as pending)
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- On UPDATE: only award badge when status changes to 'approved'
  IF TG_OP = 'UPDATE' AND NEW.status = 'approved' AND (OLD.status IS DISTINCT FROM 'approved') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.badges
      WHERE pilot_id = NEW.pilot_id
      AND badge_type = target_badge_type
    ) THEN
      INSERT INTO public.badges (
        pilot_id, course_id, course_title, course_category,
        provider, badge_type, earned_at, expires_at, is_recurrent
      ) VALUES (
        NEW.pilot_id, NULL,
        CASE
          WHEN target_badge_type = 'flight_reviewer' THEN 'Flight Reviewer'
          WHEN target_badge_type = 'roc_a_examiner' THEN 'ROC-A Examiner'
        END,
        'Permits', 'Buzz', target_badge_type, NOW(), NULL, false
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.award_permit_badge_for_license_approval() IS
'Awards Flight Reviewer or ROC-A Examiner badges when a license_approval_request status is set to approved. Matches all known ROC-A license type strings.';


-- ============================================================
-- H4 — Add admin guard to approve_test_result and reject_test_result
-- ============================================================

CREATE OR REPLACE FUNCTION public.approve_test_result(
    p_result_id UUID,
    p_reviewer_id UUID,
    p_score INTEGER,
    p_reviewer_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Admin guard: only administrators can approve test results
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND user_type = 'admin'
    ) THEN
        RAISE EXCEPTION 'Only administrators can approve test results';
    END IF;

    UPDATE public.test_results
    SET
        upload_status = 'approved',
        passed = true,
        score = p_score,
        reviewed_at = NOW(),
        reviewed_by = p_reviewer_id,
        reviewer_notes = p_reviewer_notes
    WHERE id = p_result_id;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_test_result(
    p_result_id UUID,
    p_reviewer_id UUID,
    p_reviewer_notes TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Admin guard: only administrators can reject test results
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND user_type = 'admin'
    ) THEN
        RAISE EXCEPTION 'Only administrators can reject test results';
    END IF;

    UPDATE public.test_results
    SET
        upload_status = 'rejected',
        passed = false,
        reviewed_at = NOW(),
        reviewed_by = p_reviewer_id,
        reviewer_notes = p_reviewer_notes
    WHERE id = p_result_id;

    RETURN FOUND;
END;
$$;


-- ============================================================
-- M5 — Fix beacon badge duplicate protection
-- ============================================================

-- The previous version used ON CONFLICT DO NOTHING, which doesn't
-- protect against duplicates when the id column is a random UUID.
-- Replace with IF NOT EXISTS checks.
CREATE OR REPLACE FUNCTION award_beacon_training_badge()
RETURNS TRIGGER AS $$
BEGIN
  -- Award First Aid badge for CPR training
  IF NEW.training_type = 'cpr' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.badges WHERE pilot_id = NEW.pilot_id AND badge_type = 'first_aid'
    ) THEN
      INSERT INTO public.badges (
        id,
        pilot_id,
        course_id,
        course_title,
        course_category,
        provider,
        badge_type,
        earned_at,
        expires_at,
        is_recurrent
      ) VALUES (
        gen_random_uuid(),
        NEW.pilot_id,
        NULL,
        NULL,
        NULL,
        'Red Cross',
        'first_aid',
        NEW.uploaded_at,
        NULL,
        true
      );
    END IF;
  END IF;

  -- Award Basic Fire Fighter badge for firefighting training
  IF NEW.training_type = 'firefighting' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.badges WHERE pilot_id = NEW.pilot_id AND badge_type = 'basic_firefighter'
    ) THEN
      INSERT INTO public.badges (
        id,
        pilot_id,
        course_id,
        course_title,
        course_category,
        provider,
        badge_type,
        earned_at,
        expires_at,
        is_recurrent
      ) VALUES (
        gen_random_uuid(),
        NEW.pilot_id,
        NULL,
        NULL,
        NULL,
        'USFA',
        'basic_firefighter',
        NEW.uploaded_at,
        NULL,
        true
      );
    END IF;
  END IF;

  -- Award CERT badge for CERT training
  IF NEW.training_type = 'cert' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.badges WHERE pilot_id = NEW.pilot_id AND badge_type = 'cert'
    ) THEN
      INSERT INTO public.badges (
        id,
        pilot_id,
        course_id,
        course_title,
        course_category,
        provider,
        badge_type,
        earned_at,
        expires_at,
        is_recurrent
      ) VALUES (
        gen_random_uuid(),
        NEW.pilot_id,
        NULL,
        NULL,
        NULL,
        'FEMA',
        'cert',
        NEW.uploaded_at,
        NULL,
        false
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- M6 — Add verified check to check_beacon_training_complete
-- ============================================================

-- Only count verified training records toward beacon completion.
CREATE OR REPLACE FUNCTION public.check_beacon_training_complete(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    training_count integer;
BEGIN
    SELECT COUNT(DISTINCT training_type)
    INTO training_count
    FROM public.beacon_training_progress
    WHERE pilot_id = p_pilot_id
      AND verified = true;

    -- Requires CPR, Firefighting, and CERT training (3 total)
    RETURN training_count >= 3;
END;
$$;


-- ============================================================
-- M7 — Add auth.uid() check to submit_test_result_upload
-- ============================================================

CREATE OR REPLACE FUNCTION public.submit_test_result_upload(
    p_pilot_id UUID,
    p_test_id UUID,
    p_course_id UUID,
    p_file_urls TEXT[]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result_id UUID;
BEGIN
    -- Ownership guard: pilots can only submit results for themselves
    IF p_pilot_id != auth.uid() THEN
        RAISE EXCEPTION 'Cannot submit results for another pilot';
    END IF;

    -- Insert or update test result with uploaded files
    INSERT INTO public.test_results (
        pilot_id,
        test_id,
        course_id,
        score,
        passed,
        result_file_urls,
        upload_status,
        uploaded_at,
        attempt_number
    )
    VALUES (
        p_pilot_id,
        p_test_id,
        p_course_id,
        0, -- Score is 0 until reviewed
        false, -- Not passed until approved
        p_file_urls,
        'pending',
        NOW(),
        1
    )
    ON CONFLICT (pilot_id, test_id)
    DO UPDATE SET
        result_file_urls = p_file_urls,
        upload_status = 'pending',
        uploaded_at = NOW(),
        attempt_number = test_results.attempt_number + 1
    RETURNING id INTO v_result_id;

    RETURN v_result_id;
END;
$$;


-- ============================================================
-- Grant permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.submit_test_result_upload TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_test_result TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_test_result TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_beacon_training_complete TO authenticated;
GRANT EXECUTE ON FUNCTION public.award_permit_badge_for_license_approval TO authenticated;
