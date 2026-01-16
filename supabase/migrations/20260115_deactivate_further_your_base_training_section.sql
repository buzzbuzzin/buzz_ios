-- Migration: Deactivate "FURTHER YOUR BASE TRAINING" section from UAS Pilot course
-- Description: Since units in this section have become standalone courses (Intermediate, Advanced, Specialized),
--              we no longer need to display this section in the UAS Pilot course
-- Created: 2026-01-15

-- ============================================================
-- Deactivate the "FURTHER YOUR BASE TRAINING" section
-- ============================================================

-- Mark the section as inactive (is_active = false)
-- This will hide it from the course content display in the iOS app
UPDATE public.course_sections
SET 
  is_active = false,
  updated_at = NOW()
WHERE id = '00000006-0000-0000-0000-000000000006'
  AND course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- ============================================================
-- Summary:
-- ============================================================
-- 
-- The "FURTHER YOUR BASE TRAINING" section is now deactivated for the UAS Pilot course.
-- This section originally held units 13-15 (Intermediate/Advanced training) which are now
-- standalone courses in the Academy:
-- - Intermediate Drone Pilot
-- - Intermediate Camera/Payload Operator
-- - Advanced Drone Pilot
-- - Advanced Camera/Payload Operator
-- 
-- The section record is preserved in the database for historical purposes,
-- but will not be displayed in the iOS app (is_active = false).
-- 
-- ============================================================
-- Verification query:
-- ============================================================
-- SELECT id, name, display_order, is_active 
-- FROM public.course_sections 
-- WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
-- ORDER BY display_order;
