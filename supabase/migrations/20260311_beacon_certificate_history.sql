-- Migration: Beacon Certificate History
-- Description: Allow multiple certificates per training type (refresher certs)
--              by dropping the UNIQUE constraint and updating functions to use
--              DISTINCT ON for latest-record logic.

-- 1. Drop the UNIQUE constraint that enforces one record per pilot+type
ALTER TABLE public.beacon_training_progress
DROP CONSTRAINT IF EXISTS beacon_training_progress_pilot_id_training_type_key;

-- 2. Add index for efficient latest-record lookup
CREATE INDEX IF NOT EXISTS idx_beacon_training_latest
ON public.beacon_training_progress (pilot_id, training_type, uploaded_at DESC);

-- 3. Function to return only the latest record per training type for a pilot
CREATE OR REPLACE FUNCTION public.get_latest_beacon_training(p_pilot_id uuid)
RETURNS SETOF public.beacon_training_progress
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT DISTINCT ON (training_type) *
    FROM public.beacon_training_progress
    WHERE pilot_id = p_pilot_id
      AND p_pilot_id = auth.uid()
    ORDER BY training_type, uploaded_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_latest_beacon_training(uuid) TO authenticated;

-- 4. Update check_beacon_training_complete to use DISTINCT ON subquery
CREATE OR REPLACE FUNCTION public.check_beacon_training_complete(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    training_count integer;
BEGIN
    SELECT COUNT(*) INTO training_count
    FROM (
        SELECT DISTINCT ON (training_type) training_type, expires_at
        FROM public.beacon_training_progress
        WHERE pilot_id = p_pilot_id
        ORDER BY training_type, uploaded_at DESC
    ) latest
    WHERE latest.expires_at IS NOT NULL
      AND latest.expires_at >= timezone('utc'::text, now());

    RETURN training_count >= 3;
END;
$$;

-- 5. Update sync_badges_to_beacon_training to use NOT EXISTS
--    (ON CONFLICT ... DO UPDATE is no longer valid without UNIQUE)
CREATE OR REPLACE FUNCTION public.sync_badges_to_beacon_training(p_pilot_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.beacon_training_progress (
    pilot_id, training_type, certificate_url, uploaded_at, expires_at, verified
  )
  SELECT p_pilot_id, 'cpr', 'badge-based', b.earned_at, b.expires_at, true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'first_aid'
    AND NOT EXISTS (
      SELECT 1 FROM public.beacon_training_progress
      WHERE pilot_id = p_pilot_id AND training_type = 'cpr'
    );

  INSERT INTO public.beacon_training_progress (
    pilot_id, training_type, certificate_url, uploaded_at, expires_at, verified
  )
  SELECT p_pilot_id, 'firefighting', 'badge-based', b.earned_at, b.expires_at, true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'basic_firefighter'
    AND NOT EXISTS (
      SELECT 1 FROM public.beacon_training_progress
      WHERE pilot_id = p_pilot_id AND training_type = 'firefighting'
    );

  INSERT INTO public.beacon_training_progress (
    pilot_id, training_type, certificate_url, uploaded_at, expires_at, verified
  )
  SELECT p_pilot_id, 'cert', 'badge-based', b.earned_at, b.expires_at, true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'cert'
    AND NOT EXISTS (
      SELECT 1 FROM public.beacon_training_progress
      WHERE pilot_id = p_pilot_id AND training_type = 'cert'
    );
END;
$$;
