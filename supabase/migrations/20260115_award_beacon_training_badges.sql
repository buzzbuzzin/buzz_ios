-- Migration: Award First Aid and Basic Fire Fighter Badges to Existing Beacon Pilots
-- Description: Awards badges to pilots who have already uploaded training certificates
--              and sets up automatic badge awarding for future uploads

-- ============================================================================
-- 1. Award badges to pilots who have already uploaded training certificates
-- ============================================================================

-- Award First Aid badge to pilots who have uploaded CPR certificates
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
  'Red Cross',
  'first_aid',
  btp.uploaded_at,
  NULL,
  true
FROM public.beacon_training_progress btp
WHERE btp.training_type = 'cpr'
  AND NOT EXISTS (
    SELECT 1 
    FROM public.badges b 
    WHERE b.pilot_id = btp.pilot_id 
    AND b.badge_type = 'first_aid'
  );

-- Award Basic Fire Fighter badge to pilots who have uploaded firefighting certificates
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
  'USFA',
  'basic_firefighter',
  btp.uploaded_at,
  NULL,
  true
FROM public.beacon_training_progress btp
WHERE btp.training_type = 'firefighting'
  AND NOT EXISTS (
    SELECT 1 
    FROM public.badges b 
    WHERE b.pilot_id = btp.pilot_id 
    AND b.badge_type = 'basic_firefighter'
  );

-- ============================================================================
-- 2. Create trigger to automatically award badges on future certificate uploads
-- ============================================================================

-- Function to automatically award badge when training certificate is uploaded
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
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for automatic badge awarding on future uploads
DROP TRIGGER IF EXISTS trigger_award_beacon_training_badge ON public.beacon_training_progress;

CREATE TRIGGER trigger_award_beacon_training_badge
AFTER INSERT ON public.beacon_training_progress
FOR EACH ROW
EXECUTE FUNCTION award_beacon_training_badge();
