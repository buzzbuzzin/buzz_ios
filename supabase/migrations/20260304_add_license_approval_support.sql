-- Migration: Add license approval workflow support
-- Created: 2026-03-04
-- Description: Adds approval columns to pilot_licenses and updates badge trigger
-- to only award badges after admin approval

-- Step 1: Add approval columns to pilot_licenses table
ALTER TABLE public.pilot_licenses
ADD COLUMN IF NOT EXISTS approval_status TEXT CHECK (approval_status IN ('pending', 'approved', 'rejected')),
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id),
ADD COLUMN IF NOT EXISTS reviewer_notes TEXT;

-- Step 2: Update the badge trigger function to only award on approval
CREATE OR REPLACE FUNCTION public.award_permit_badge_for_license()
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
  ELSIF NEW.license_type = 'ROC-A Examiner (CAN)' THEN
    target_badge_type := 'roc_a_examiner';
  ELSE
    -- No permit badge for this license type
    RETURN NEW;
  END IF;

  -- On INSERT: skip badge award for reviewable licenses (they start as pending)
  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- On UPDATE: only award badge when approval_status changes to 'approved'
  IF TG_OP = 'UPDATE' AND NEW.approval_status = 'approved' AND (OLD.approval_status IS DISTINCT FROM 'approved') THEN
    -- Check if pilot already has this badge
    IF NOT EXISTS (
      SELECT 1 FROM public.badges
      WHERE pilot_id = NEW.pilot_id
      AND badge_type = target_badge_type
    ) THEN
      -- Award the badge
      INSERT INTO public.badges (
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
        NEW.pilot_id,
        NULL,
        CASE
          WHEN target_badge_type = 'flight_reviewer' THEN 'Flight Reviewer'
          WHEN target_badge_type = 'roc_a_examiner' THEN 'ROC-A Examiner'
        END,
        'Permits',
        'Buzz',
        target_badge_type,
        NOW(),
        NULL,
        false
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Step 3: Recreate trigger to fire on INSERT OR UPDATE
DROP TRIGGER IF EXISTS trigger_award_permit_badge ON public.pilot_licenses;

CREATE TRIGGER trigger_award_permit_badge
AFTER INSERT OR UPDATE ON public.pilot_licenses
FOR EACH ROW
EXECUTE FUNCTION public.award_permit_badge_for_license();

COMMENT ON FUNCTION public.award_permit_badge_for_license() IS
'Awards Flight Reviewer or ROC-A Examiner badges only when approval_status is set to approved by admin';
