-- Migration: Refactor license approval workflow to dedicated table
-- Created: 2026-03-04
-- Description: Moves approval workflow from inline columns on pilot_licenses
-- to a dedicated license_approval_requests table (like express_promotion_applications)

-- Step 1: Create the license_approval_requests table
CREATE TABLE IF NOT EXISTS public.license_approval_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pilot_id UUID NOT NULL REFERENCES public.profiles(id),
  license_id UUID NOT NULL REFERENCES public.pilot_licenses(id) ON DELETE CASCADE,
  license_type TEXT NOT NULL,
  file_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewer_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Step 2: Enable RLS + policies
ALTER TABLE public.license_approval_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pilots can view their own approval requests"
ON public.license_approval_requests
FOR SELECT
USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own approval requests"
ON public.license_approval_requests
FOR INSERT
WITH CHECK (auth.uid() = pilot_id);

-- Step 3: Migrate existing data from inline columns
INSERT INTO public.license_approval_requests (
  pilot_id, license_id, license_type, file_url, status,
  submitted_at, reviewed_at, reviewed_by, reviewer_notes, created_at, updated_at
)
SELECT
  pl.pilot_id,
  pl.id,
  pl.license_type,
  pl.file_url,
  pl.approval_status,
  pl.uploaded_at,
  pl.reviewed_at,
  pl.reviewed_by,
  pl.reviewer_notes,
  pl.uploaded_at,
  COALESCE(pl.reviewed_at, pl.uploaded_at)
FROM public.pilot_licenses pl
WHERE pl.approval_status IS NOT NULL;

-- Step 4: Drop old triggers and their functions
DROP TRIGGER IF EXISTS trigger_protect_approval_columns ON public.pilot_licenses;
DROP FUNCTION IF EXISTS public.protect_license_approval_columns();

DROP TRIGGER IF EXISTS trigger_award_permit_badge ON public.pilot_licenses;
DROP FUNCTION IF EXISTS public.award_permit_badge_for_license();

-- Step 5: Create new badge trigger on license_approval_requests
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
  ELSIF NEW.license_type = 'ROC-A Examiner (CAN)' THEN
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

CREATE TRIGGER trigger_award_permit_badge_approval
AFTER INSERT OR UPDATE ON public.license_approval_requests
FOR EACH ROW
EXECUTE FUNCTION public.award_permit_badge_for_license_approval();

COMMENT ON FUNCTION public.award_permit_badge_for_license_approval() IS
'Awards Flight Reviewer or ROC-A Examiner badges when a license_approval_request status is set to approved';

-- Step 6: Drop inline approval columns from pilot_licenses
ALTER TABLE public.pilot_licenses
DROP COLUMN IF EXISTS approval_status,
DROP COLUMN IF EXISTS reviewed_at,
DROP COLUMN IF EXISTS reviewed_by,
DROP COLUMN IF EXISTS reviewer_notes;

-- Step 7: Add indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_license_approval_requests_pilot_id
ON public.license_approval_requests(pilot_id);

CREATE INDEX IF NOT EXISTS idx_license_approval_requests_license_id
ON public.license_approval_requests(license_id);

CREATE INDEX IF NOT EXISTS idx_license_approval_requests_status
ON public.license_approval_requests(status);
