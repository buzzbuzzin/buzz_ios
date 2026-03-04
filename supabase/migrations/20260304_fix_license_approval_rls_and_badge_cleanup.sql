-- Fix #1 (CRITICAL): Remove overly permissive ALL policy and add proper UPDATE policy
-- Fix #2 (HIGH): Clean up incorrectly awarded ROC-A examiner badges

-- Step 1: Drop the overly permissive ALL policy
DROP POLICY IF EXISTS "Allow authenticated users full access to pilot_licenses" ON public.pilot_licenses;

-- Step 2: Add UPDATE policy - pilots can only update their own rows
CREATE POLICY "Pilots can update their own licenses"
ON public.pilot_licenses
FOR UPDATE
USING (auth.uid() = pilot_id)
WITH CHECK (auth.uid() = pilot_id);

-- Step 3: Add a BEFORE UPDATE trigger to protect approval columns from non-admin users
-- When using service role (edge functions), auth.uid() is NULL, so approval columns can be modified.
-- When a regular authenticated user updates, approval columns are silently preserved.
CREATE OR REPLACE FUNCTION public.protect_license_approval_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If auth.uid() is set, this is a regular user (not service role)
  -- Prevent them from modifying approval columns
  IF auth.uid() IS NOT NULL THEN
    NEW.approval_status := OLD.approval_status;
    NEW.reviewed_at := OLD.reviewed_at;
    NEW.reviewed_by := OLD.reviewed_by;
    NEW.reviewer_notes := OLD.reviewer_notes;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_protect_approval_columns ON public.pilot_licenses;

CREATE TRIGGER trigger_protect_approval_columns
BEFORE UPDATE ON public.pilot_licenses
FOR EACH ROW
EXECUTE FUNCTION public.protect_license_approval_columns();

COMMENT ON FUNCTION public.protect_license_approval_columns() IS
'Prevents regular users from modifying approval_status, reviewed_at, reviewed_by, reviewer_notes. Only service role (edge functions) can update these columns.';

-- Step 4: Clean up incorrectly awarded roc_a_examiner badges
-- The original trigger (20251129) used 'ROC-A (CAN)' which is the basic radio cert,
-- not the examiner cert. This means ROC-A holders were incorrectly awarded examiner badges.
DELETE FROM public.badges b
WHERE b.badge_type = 'roc_a_examiner'
AND NOT EXISTS (
  SELECT 1 FROM public.pilot_licenses pl
  WHERE pl.pilot_id = b.pilot_id
  AND pl.license_type = 'ROC-A Examiner (CAN)'
);
