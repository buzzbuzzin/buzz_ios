-- Migration: Add permit badge types (flight_reviewer and roc_a_examiner)
-- Created: 2025-11-29
-- Description: Adds support for Flight Reviewer and ROC-A Examiner permit badges

-- Step 1: Update the badges table to support new permit badge types
ALTER TABLE public.badges
DROP CONSTRAINT IF EXISTS badges_badge_type_check;

ALTER TABLE public.badges
ADD CONSTRAINT badges_badge_type_check 
CHECK (badge_type = ANY (ARRAY['course'::text, 'ex_military'::text, 'buzz'::text, 'government_employee'::text, 'faa'::text, 'flight_reviewer'::text, 'roc_a_examiner'::text]));

-- Step 2: Update the badges_catalog table to support new permit badge types
ALTER TABLE public.badges_catalog
DROP CONSTRAINT IF EXISTS badges_catalog_badge_type_check;

ALTER TABLE public.badges_catalog
ADD CONSTRAINT badges_catalog_badge_type_check 
CHECK (badge_type = ANY (ARRAY['course'::text, 'ex_military'::text, 'buzz'::text, 'government_employee'::text, 'faa'::text, 'flight_reviewer'::text, 'roc_a_examiner'::text]));

-- Step 3: Insert permit badge definitions into badges_catalog
INSERT INTO public.badges_catalog (
  badge_type,
  title,
  category,
  course_id,
  icon_name,
  color_name,
  provider,
  is_recurrent,
  is_active,
  display_order
) VALUES 
  (
    'flight_reviewer',
    'Flight Reviewer',
    'Permits',
    NULL,
    'person.text.rectangle.fill',
    'teal',
    'Buzz',
    false,
    true,
    100
  ),
  (
    'roc_a_examiner',
    'ROC-A Examiner',
    'Permits',
    NULL,
    'antenna.radiowaves.left.and.right',
    'indigo',
    'Buzz',
    false,
    true,
    101
  )
ON CONFLICT (id) DO NOTHING;

-- Optional: Create a function to auto-award permit badges based on license uploads
-- This function can be called from the application or triggered automatically
CREATE OR REPLACE FUNCTION public.award_permit_badge_for_license()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_badge_type TEXT;
BEGIN
  -- Determine which badge to award based on license type
  IF NEW.license_type = 'RPA Flight Reviewer (CAN)' THEN
    target_badge_type := 'flight_reviewer';
  ELSIF NEW.license_type = 'ROC-A Certificate (CAN)' THEN
    target_badge_type := 'roc_a_examiner';
  ELSE
    -- No permit badge for this license type
    RETURN NEW;
  END IF;

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

  RETURN NEW;
END;
$$;

-- Create a trigger to auto-award badges when licenses are uploaded
DROP TRIGGER IF EXISTS trigger_award_permit_badge ON public.pilot_licenses;

CREATE TRIGGER trigger_award_permit_badge
AFTER INSERT ON public.pilot_licenses
FOR EACH ROW
EXECUTE FUNCTION public.award_permit_badge_for_license();

-- Note: The trigger automatically awards permit badges when licenses are uploaded.
-- The iOS app will sync badges after upload to display the newly awarded badges.

COMMENT ON FUNCTION public.award_permit_badge_for_license() IS 
'Automatically awards Flight Reviewer or ROC-A Examiner badges when corresponding licenses are uploaded';

-- Optional: Function to retroactively award badges for existing licenses
-- Run this after migration if you have existing licenses that should receive badges
CREATE OR REPLACE FUNCTION public.award_permit_badges_for_existing_licenses()
RETURNS TABLE (
  pilot_id UUID,
  badge_type TEXT,
  license_type TEXT,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  license_record RECORD;
  target_badge_type TEXT;
  badge_already_exists BOOLEAN;
BEGIN
  -- Loop through all licenses that qualify for permit badges
  FOR license_record IN 
    SELECT pl.pilot_id, pl.license_type, pl.id as license_id
    FROM public.pilot_licenses pl
    WHERE pl.license_type IN ('RPA Flight Reviewer (CAN)', 'ROC-A Certificate (CAN)')
  LOOP
    -- Determine badge type
    IF license_record.license_type = 'RPA Flight Reviewer (CAN)' THEN
      target_badge_type := 'flight_reviewer';
    ELSIF license_record.license_type = 'ROC-A Certificate (CAN)' THEN
      target_badge_type := 'roc_a_examiner';
    ELSE
      CONTINUE;
    END IF;

    -- Check if badge already exists
    SELECT EXISTS(
      SELECT 1 FROM public.badges
      WHERE badges.pilot_id = license_record.pilot_id
      AND badges.badge_type = target_badge_type
    ) INTO badge_already_exists;

    IF badge_already_exists THEN
      -- Return status: already has badge
      pilot_id := license_record.pilot_id;
      badge_type := target_badge_type;
      license_type := license_record.license_type;
      status := 'already_exists';
      RETURN NEXT;
    ELSE
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
        license_record.pilot_id,
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

      -- Return status: newly awarded
      pilot_id := license_record.pilot_id;
      badge_type := target_badge_type;
      license_type := license_record.license_type;
      status := 'awarded';
      RETURN NEXT;
    END IF;
  END LOOP;

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.award_permit_badges_for_existing_licenses() IS 
'One-time function to retroactively award permit badges for licenses that were uploaded before this migration. Returns a table showing which pilots received which badges.';

-- To run this function after migration, execute:
-- SELECT * FROM public.award_permit_badges_for_existing_licenses();

