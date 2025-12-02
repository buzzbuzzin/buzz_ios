-- Migration: Add course_sections table for configurable course structure
-- This allows section names and unit-section relationships to be managed from the backend

-- Create course_sections table
CREATE TABLE public.course_sections (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  course_id uuid NOT NULL,
  name text NOT NULL,                          -- Section name (e.g., "MANDATORY UNITS", "BASE PROGRAM")
  display_order integer NOT NULL,              -- Order in which sections appear (1, 2, 3, etc.)
  description text,                            -- Optional description for the section
  section_type text DEFAULT 'units',           -- Type: 'units', 'test', 'recurrent' (for special handling)
  requires_subscription boolean DEFAULT false, -- Whether units in this section require subscription
  requires_test_passed boolean DEFAULT false,  -- Whether units require passing a prerequisite test
  prerequisite_section_id uuid,                -- Optional: section that must be completed first
  is_active boolean DEFAULT true,              -- Whether this section is currently active/visible
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT course_sections_pkey PRIMARY KEY (id),
  CONSTRAINT course_sections_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.training_courses(id) ON DELETE CASCADE,
  CONSTRAINT course_sections_prerequisite_fkey FOREIGN KEY (prerequisite_section_id) REFERENCES public.course_sections(id) ON DELETE SET NULL
);

-- Add section_id column to course_units table
ALTER TABLE public.course_units 
ADD COLUMN section_id uuid,
ADD CONSTRAINT course_units_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.course_sections(id) ON DELETE SET NULL;

-- Create index for faster lookups
CREATE INDEX idx_course_sections_course_id ON public.course_sections(course_id);
CREATE INDEX idx_course_sections_display_order ON public.course_sections(course_id, display_order);
CREATE INDEX idx_course_units_section_id ON public.course_units(section_id);

-- Enable RLS on course_sections
ALTER TABLE public.course_sections ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Anyone can read course sections
CREATE POLICY "Anyone can view course sections"
ON public.course_sections FOR SELECT
USING (true);

-- RLS Policy: Only admins can modify course sections (adjust as needed)
CREATE POLICY "Admins can manage course sections"
ON public.course_sections FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- ============================================================
-- Migrate existing UAS Pilot Course data to new structure
-- ============================================================

-- Insert sections for UAS Pilot Course (ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890)
INSERT INTO public.course_sections (id, course_id, name, display_order, section_type, requires_subscription, requires_test_passed)
VALUES
  -- Section 1: Mandatory Units (free, no test required)
  (
    '00000001-0000-0000-0000-000000000001',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'MANDATORY UNITS',
    1,
    'units',
    false,
    false
  ),
  -- Section 2: Ground School Test
  (
    '00000002-0000-0000-0000-000000000002',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'GROUND SCHOOL TEST',
    2,
    'test',
    false,
    false
  ),
  -- Section 3: Base Program (Step 1) - requires test passed
  (
    '00000003-0000-0000-0000-000000000003',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'BASE PROGRAM',
    3,
    'units',
    false,
    true
  ),
  -- Section 4: Recurrent Training - requires test passed + subscription
  (
    '00000004-0000-0000-0000-000000000004',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'RECURRENT TRAINING',
    4,
    'recurrent',
    true,
    true
  ),
  -- Section 5: Extension Courses (Step 2) - requires test passed + subscription for units 5+
  (
    '00000005-0000-0000-0000-000000000005',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'EXTENSION COURSES',
    5,
    'units',
    true,
    true
  ),
  -- Section 6: Further Your Base Training (Step 3) - requires test passed + subscription
  (
    '00000006-0000-0000-0000-000000000006',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'FURTHER YOUR BASE TRAINING',
    6,
    'units',
    true,
    true
  );

-- Update existing units to reference new sections
-- Map is_mandatory = true units to MANDATORY UNITS section
UPDATE public.course_units
SET section_id = '00000001-0000-0000-0000-000000000001'
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
  AND is_mandatory = true;

-- Map step_number = 1 units to BASE PROGRAM section
UPDATE public.course_units
SET section_id = '00000003-0000-0000-0000-000000000003'
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
  AND step_number = 1
  AND (is_mandatory = false OR is_mandatory IS NULL);

-- Map step_number = 2 units to EXTENSION COURSES section
UPDATE public.course_units
SET section_id = '00000005-0000-0000-0000-000000000005'
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
  AND step_number = 2;

-- Map step_number = 3 units to FURTHER YOUR BASE TRAINING section
UPDATE public.course_units
SET section_id = '00000006-0000-0000-0000-000000000006'
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
  AND step_number = 3;

-- ============================================================
-- Comments for future reference
-- ============================================================
-- 
-- After this migration:
-- 1. The old columns (step_number, is_mandatory) are kept for backward compatibility
-- 2. The iOS app should be updated to fetch sections and use section_id
-- 3. Once all platforms are updated, the old columns can be removed with:
--    ALTER TABLE public.course_units DROP COLUMN step_number;
--    ALTER TABLE public.course_units DROP COLUMN is_mandatory;
--
-- To add a new section:
--   INSERT INTO course_sections (course_id, name, display_order, ...)
--   VALUES ('course-uuid', 'NEW SECTION NAME', 7, ...);
--
-- To move a unit to a different section:
--   UPDATE course_units SET section_id = 'new-section-uuid' WHERE id = 'unit-uuid';
--
-- To reorder sections:
--   UPDATE course_sections SET display_order = 2 WHERE id = 'section-uuid';

