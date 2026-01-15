-- Migration: Add CERT as Third Requirement for Beacon Program
-- Description: Adds CERT (Community Emergency Response Team) as a required training
--              for beacon program signup. Also implements badge checking logic so that
--              pilots who already have CERT badge will have their requirement fulfilled.

-- ============================================================================
-- 1. Update training_type constraint to include 'cert'
-- ============================================================================

-- Update beacon_training_progress table to allow 'cert' training type
ALTER TABLE public.beacon_training_progress 
DROP CONSTRAINT IF EXISTS beacon_training_progress_training_type_check;

ALTER TABLE public.beacon_training_progress 
ADD CONSTRAINT beacon_training_progress_training_type_check 
CHECK (training_type = ANY (ARRAY['cpr'::text, 'firefighting'::text, 'cert'::text]));

-- ============================================================================
-- 2. Update check_beacon_training_complete function to require 3 trainings
-- ============================================================================

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
    WHERE pilot_id = p_pilot_id;
    
    -- Requires CPR, Firefighting, and CERT training (3 total)
    RETURN training_count >= 3;
END;
$$;

-- ============================================================================
-- 3. Update award_beacon_training_badge trigger to handle CERT badge
-- ============================================================================

CREATE OR REPLACE FUNCTION award_beacon_training_badge()
RETURNS TRIGGER AS $$
BEGIN
  -- Award First Aid badge for CPR training
  IF NEW.training_type = 'cpr' THEN
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
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Award Basic Fire Fighter badge for firefighting training
  IF NEW.training_type = 'firefighting' THEN
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
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Award CERT badge for CERT training
  IF NEW.training_type = 'cert' THEN
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
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. Create function to check if pilot has badge and auto-fulfill training
-- ============================================================================

-- Function to check if pilot has earned badges and create training progress records
-- This allows pilots who already have First Aid, Basic Firefighter, or CERT badges
-- to have those requirements fulfilled automatically when checking beacon eligibility
CREATE OR REPLACE FUNCTION sync_badges_to_beacon_training(p_pilot_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If pilot has First Aid badge but no CPR training record, create one
  INSERT INTO public.beacon_training_progress (
    pilot_id,
    training_type,
    certificate_url,
    uploaded_at,
    verified
  )
  SELECT 
    p_pilot_id,
    'cpr',
    'badge-based',
    b.earned_at,
    true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'first_aid'
    AND NOT EXISTS (
      SELECT 1 
      FROM public.beacon_training_progress btp 
      WHERE btp.pilot_id = p_pilot_id 
      AND btp.training_type = 'cpr'
    )
  LIMIT 1;
  
  -- If pilot has Basic Fire Fighter badge but no firefighting training record, create one
  INSERT INTO public.beacon_training_progress (
    pilot_id,
    training_type,
    certificate_url,
    uploaded_at,
    verified
  )
  SELECT 
    p_pilot_id,
    'firefighting',
    'badge-based',
    b.earned_at,
    true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'basic_firefighter'
    AND NOT EXISTS (
      SELECT 1 
      FROM public.beacon_training_progress btp 
      WHERE btp.pilot_id = p_pilot_id 
      AND btp.training_type = 'firefighting'
    )
  LIMIT 1;
  
  -- If pilot has CERT badge but no cert training record, create one
  INSERT INTO public.beacon_training_progress (
    pilot_id,
    training_type,
    certificate_url,
    uploaded_at,
    verified
  )
  SELECT 
    p_pilot_id,
    'cert',
    'badge-based',
    b.earned_at,
    true
  FROM public.badges b
  WHERE b.pilot_id = p_pilot_id
    AND b.badge_type = 'cert'
    AND NOT EXISTS (
      SELECT 1 
      FROM public.beacon_training_progress btp 
      WHERE btp.pilot_id = p_pilot_id 
      AND btp.training_type = 'cert'
    )
  LIMIT 1;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.sync_badges_to_beacon_training(uuid) TO authenticated;

-- ============================================================================
-- 5. Update enroll_beacon_volunteer function to sync badges first
-- ============================================================================

CREATE OR REPLACE FUNCTION public.enroll_beacon_volunteer(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- First, sync any existing badges to training progress
    PERFORM public.sync_badges_to_beacon_training(p_pilot_id);
    
    -- Check if training is complete (now requires 3 trainings)
    IF NOT public.check_beacon_training_complete(p_pilot_id) THEN
        RAISE EXCEPTION 'Training requirements not met. Please complete CPR, Firefighting, and CERT training.';
    END IF;
    
    -- Insert volunteer record
    INSERT INTO public.beacon_volunteers (pilot_id)
    VALUES (p_pilot_id)
    ON CONFLICT (pilot_id) DO NOTHING;
    
    -- Update profile
    UPDATE public.profiles
    SET is_beacon_volunteer = true
    WHERE id = p_pilot_id;
    
    RETURN true;
END;
$$;

-- ============================================================================
-- 6. Award CERT badges to pilots who already uploaded CERT certificates
-- ============================================================================

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
)
SELECT 
  gen_random_uuid(),
  btp.pilot_id,
  NULL,
  NULL,
  NULL,
  'FEMA',
  'cert',
  btp.uploaded_at,
  NULL,
  false
FROM public.beacon_training_progress btp
WHERE btp.training_type = 'cert'
  AND NOT EXISTS (
    SELECT 1 
    FROM public.badges b 
    WHERE b.pilot_id = btp.pilot_id 
    AND b.badge_type = 'cert'
  );
