-- Migration: Add expiration tracking for Beacon qualifications
-- Description: Stores expiration dates on Beacon training records, requires
--              non-expired certifications for volunteer eligibility, and
--              propagates expiration updates to related Beacon badges.

ALTER TABLE public.beacon_training_progress
ADD COLUMN IF NOT EXISTS expires_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_beacon_training_progress_expires_at
ON public.beacon_training_progress (expires_at);

-- Keep Beacon badges aligned with the source training record when a
-- certificate is uploaded or renewed.
CREATE OR REPLACE FUNCTION public.award_beacon_training_badge()
RETURNS TRIGGER AS $$
DECLARE
  target_badge_type text;
  target_provider text;
  target_recurrent boolean;
BEGIN
  IF NEW.training_type = 'cpr' THEN
    target_badge_type := 'first_aid';
    target_provider := 'Red Cross';
    target_recurrent := true;
  ELSIF NEW.training_type = 'firefighting' THEN
    target_badge_type := 'basic_firefighter';
    target_provider := 'USFA';
    target_recurrent := true;
  ELSIF NEW.training_type = 'cert' THEN
    target_badge_type := 'cert';
    target_provider := 'FEMA';
    target_recurrent := false;
  ELSE
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.badges
    WHERE pilot_id = NEW.pilot_id
      AND badge_type = target_badge_type
  ) THEN
    UPDATE public.badges
    SET earned_at = NEW.uploaded_at,
        expires_at = NEW.expires_at,
        provider = target_provider,
        is_recurrent = target_recurrent
    WHERE pilot_id = NEW.pilot_id
      AND badge_type = target_badge_type;
  ELSE
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
      target_provider,
      target_badge_type,
      NEW.uploaded_at,
      NEW.expires_at,
      target_recurrent
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_award_beacon_training_badge ON public.beacon_training_progress;

CREATE TRIGGER trigger_award_beacon_training_badge
AFTER INSERT OR UPDATE ON public.beacon_training_progress
FOR EACH ROW
EXECUTE FUNCTION public.award_beacon_training_badge();

-- Badge-derived Beacon qualifications should carry badge expiration forward so
-- existing pilots can backfill the missing values instead of losing the record.
CREATE OR REPLACE FUNCTION public.sync_badges_to_beacon_training(p_pilot_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.beacon_training_progress (
    pilot_id,
    training_type,
    certificate_url,
    uploaded_at,
    expires_at,
    verified
  )
  SELECT
    p_pilot_id,
    'cpr',
    'badge-based',
    b.earned_at,
    b.expires_at,
    true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'first_aid'
  ON CONFLICT (pilot_id, training_type) DO UPDATE
  SET expires_at = COALESCE(EXCLUDED.expires_at, public.beacon_training_progress.expires_at);

  INSERT INTO public.beacon_training_progress (
    pilot_id,
    training_type,
    certificate_url,
    uploaded_at,
    expires_at,
    verified
  )
  SELECT
    p_pilot_id,
    'firefighting',
    'badge-based',
    b.earned_at,
    b.expires_at,
    true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'basic_firefighter'
  ON CONFLICT (pilot_id, training_type) DO UPDATE
  SET expires_at = COALESCE(EXCLUDED.expires_at, public.beacon_training_progress.expires_at);

  INSERT INTO public.beacon_training_progress (
    pilot_id,
    training_type,
    certificate_url,
    uploaded_at,
    expires_at,
    verified
  )
  SELECT
    p_pilot_id,
    'cert',
    'badge-based',
    b.earned_at,
    b.expires_at,
    true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'cert'
  ON CONFLICT (pilot_id, training_type) DO UPDATE
  SET expires_at = COALESCE(EXCLUDED.expires_at, public.beacon_training_progress.expires_at);
END;
$$;

-- Beacon eligibility now requires every required qualification to be recorded,
-- have an expiration date, and still be valid. The app currently does not have
-- a separate admin verification workflow for these rows, so expiration is the
-- enforceable source of truth.
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
      AND expires_at IS NOT NULL
      AND expires_at >= timezone('utc'::text, now());

    RETURN training_count >= 3;
END;
$$;

-- Emergency dispatch should only return volunteers whose Beacon
-- qualifications are still active.
CREATE OR REPLACE FUNCTION public.find_nearby_beacon_volunteers(
    p_lat double precision,
    p_lng double precision,
    p_radius_miles integer DEFAULT 25
)
RETURNS TABLE (
    volunteer_id uuid,
    pilot_id uuid,
    distance_miles double precision,
    notification_radius_miles integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        bv.id as volunteer_id,
        bv.pilot_id,
        (3959 * acos(
            cos(radians(p_lat)) * cos(radians(bv.last_location_lat)) *
            cos(radians(bv.last_location_lng) - radians(p_lng)) +
            sin(radians(p_lat)) * sin(radians(bv.last_location_lat))
        )) as distance_miles,
        bv.notification_radius_miles
    FROM public.beacon_volunteers bv
    WHERE bv.is_available = true
        AND public.check_beacon_training_complete(bv.pilot_id)
        AND bv.last_location_lat IS NOT NULL
        AND bv.last_location_lng IS NOT NULL
        AND (3959 * acos(
            cos(radians(p_lat)) * cos(radians(bv.last_location_lat)) *
            cos(radians(bv.last_location_lng) - radians(p_lng)) +
            sin(radians(p_lat)) * sin(radians(bv.last_location_lat))
        )) <= LEAST(p_radius_miles, bv.notification_radius_miles)
    ORDER BY distance_miles;
END;
$$;

-- Backfill Beacon training expiration values from matching badges where those
-- badge rows already have an expiration, then keep badge expiration values in
-- sync with the source training record so both UI surfaces agree.
UPDATE public.beacon_training_progress btp
SET expires_at = b.expires_at
FROM public.badges b
WHERE btp.expires_at IS NULL
  AND b.expires_at IS NOT NULL
  AND b.pilot_id = btp.pilot_id
  AND (
    (btp.training_type = 'cpr' AND b.badge_type = 'first_aid') OR
    (btp.training_type = 'firefighting' AND b.badge_type = 'basic_firefighter') OR
    (btp.training_type = 'cert' AND b.badge_type = 'cert')
  );

-- Backfill badge expiration values from the source training record where
-- possible so the badge UI stays consistent with Beacon qualification state.
UPDATE public.badges b
SET expires_at = btp.expires_at,
    earned_at = btp.uploaded_at
FROM public.beacon_training_progress btp
WHERE b.pilot_id = btp.pilot_id
  AND (
    (btp.training_type = 'cpr' AND b.badge_type = 'first_aid') OR
    (btp.training_type = 'firefighting' AND b.badge_type = 'basic_firefighter') OR
    (btp.training_type = 'cert' AND b.badge_type = 'cert')
  );

GRANT EXECUTE ON FUNCTION public.sync_badges_to_beacon_training(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_beacon_training_complete(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_nearby_beacon_volunteers(double precision, double precision, integer) TO authenticated;
