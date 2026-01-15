-- Migration: Add FEMA Provider and CERT Badge
-- Description: Adds FEMA as a training course provider and creates the CERT 
--              (Community Emergency Response Team) badge type for emergency response training

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
-- 2. Update badge_type constraints to include CERT
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
  'cert'::text
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
  'cert'::text
]));

-- ============================================================================
-- 3. Add CERT badge to badges_catalog
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
