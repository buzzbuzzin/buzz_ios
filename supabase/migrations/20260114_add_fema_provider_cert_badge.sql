-- Migration: Add FEMA Provider and Emergency Response Badges
-- Description: Adds FEMA as a training course provider and creates emergency response badges:
--              - CERT (Community Emergency Response Team)
--              - First Aid (required for Beacon program)
--              - Basic Fire Fighter (required for Beacon program)

-- ============================================================================
-- 1. Update provider constraints to include FEMA
-- ============================================================================

-- Update badges table provider constraint
ALTER TABLE public.badges 
DROP CONSTRAINT IF EXISTS badges_provider_check;

ALTER TABLE public.badges 
ADD CONSTRAINT badges_provider_check 
CHECK (provider = ANY (ARRAY[
  'Buzz'::text, 
  'Red Cross'::text, 
  'USFA'::text, 
  'FEMA'::text,
  'Amazon'::text, 
  'T-Mobile'::text, 
  'Other'::text
]));

-- Update badges_catalog table provider constraint
ALTER TABLE public.badges_catalog 
DROP CONSTRAINT IF EXISTS badges_catalog_provider_check;

ALTER TABLE public.badges_catalog 
ADD CONSTRAINT badges_catalog_provider_check 
CHECK (provider = ANY (ARRAY[
  'Buzz'::text, 
  'Red Cross'::text, 
  'USFA'::text, 
  'FEMA'::text,
  'Amazon'::text, 
  'T-Mobile'::text, 
  'Other'::text
]));

-- Update training_courses table provider constraint
ALTER TABLE public.training_courses 
DROP CONSTRAINT IF EXISTS training_courses_provider_check;

ALTER TABLE public.training_courses 
ADD CONSTRAINT training_courses_provider_check 
CHECK (provider = ANY (ARRAY[
  'Buzz'::text, 
  'Red Cross'::text, 
  'USFA'::text, 
  'FEMA'::text,
  'Amazon'::text, 
  'T-Mobile'::text, 
  'Other'::text
]));

-- ============================================================================
-- 2. Update badge_type constraints to include CERT, First Aid, Basic Fire Fighter
-- ============================================================================

-- Update badges table badge_type constraint
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
  'beacon_volunteer'::text,
  'cert'::text,
  'first_aid'::text,
  'basic_firefighter'::text
]));

-- Update badges_catalog table badge_type constraint
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
  'beacon_volunteer'::text,
  'cert'::text,
  'first_aid'::text,
  'basic_firefighter'::text
]));

-- ============================================================================
-- 3. Add emergency response badges to badges_catalog
-- ============================================================================

-- Insert CERT badge definition
-- CERT (Community Emergency Response Team) is a FEMA program that trains
-- volunteers to help their communities during disasters
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
  'cert',
  'CERT',
  'Emergency Response',
  'shield.checkered',
  'green',
  'FEMA',
  false,
  true,
  101
) ON CONFLICT DO NOTHING;

-- Insert First Aid badge definition
-- Required for Beacon program qualification - pilots upload CPR/First Aid certificate
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
  'first_aid',
  'First Aid',
  'Emergency Response',
  'cross.case.fill',
  'red',
  'Red Cross',
  true,
  true,
  102
) ON CONFLICT DO NOTHING;

-- Insert Basic Fire Fighter badge definition
-- Required for Beacon program qualification - pilots upload firefighter training certificate
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
  'basic_firefighter',
  'Basic Fire Fighter',
  'Emergency Response',
  'flame.fill',
  'orange',
  'USFA',
  true,
  true,
  103
) ON CONFLICT DO NOTHING;
