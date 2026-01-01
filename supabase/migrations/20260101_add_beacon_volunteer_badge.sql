-- Add beacon_volunteer badge type to badges table
-- This migration adds support for Beacon Volunteer badges

-- Update the badge_type check constraint on badges table to include beacon_volunteer
ALTER TABLE public.badges 
DROP CONSTRAINT IF EXISTS badges_badge_type_check;

ALTER TABLE public.badges 
ADD CONSTRAINT badges_badge_type_check 
CHECK (badge_type = ANY (ARRAY[
  'course'::text, 
  'ex_military'::text, 
  'buzz'::text, 
  'government_employee'::text, 
  'faa'::text, 
  'flight_reviewer'::text, 
  'roc_a_examiner'::text,
  'beacon_volunteer'::text
]));

-- Update the badge_type check constraint on badges_catalog table to include beacon_volunteer
ALTER TABLE public.badges_catalog 
DROP CONSTRAINT IF EXISTS badges_catalog_badge_type_check;

ALTER TABLE public.badges_catalog 
ADD CONSTRAINT badges_catalog_badge_type_check 
CHECK (badge_type = ANY (ARRAY[
  'course'::text, 
  'ex_military'::text, 
  'buzz'::text, 
  'government_employee'::text, 
  'faa'::text, 
  'flight_reviewer'::text, 
  'roc_a_examiner'::text,
  'beacon_volunteer'::text
]));

-- Add beacon_volunteer badge to badges_catalog
INSERT INTO public.badges_catalog (
  id,
  badge_type,
  title,
  category,
  icon_name,
  color_name,
  provider,
  is_recurrent,
  is_active,
  display_order
) VALUES (
  gen_random_uuid(),
  'beacon_volunteer',
  'Beacon Volunteer',
  'Service Recognition',
  'antenna.radiowaves.left.and.right',
  'orange',
  'Buzz',
  false,
  true,
  100
) ON CONFLICT DO NOTHING;

-- Create a function to automatically award Beacon Volunteer badge on enrollment
CREATE OR REPLACE FUNCTION award_beacon_volunteer_badge()
RETURNS TRIGGER AS $$
BEGIN
  -- Award badge to the pilot who just became a Beacon volunteer
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
    'Buzz',
    'beacon_volunteer',
    NOW(),
    NULL,
    false
  )
  ON CONFLICT DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically award badge on beacon volunteer enrollment
DROP TRIGGER IF EXISTS trigger_award_beacon_volunteer_badge ON public.beacon_volunteers;

CREATE TRIGGER trigger_award_beacon_volunteer_badge
AFTER INSERT ON public.beacon_volunteers
FOR EACH ROW
EXECUTE FUNCTION award_beacon_volunteer_badge();

