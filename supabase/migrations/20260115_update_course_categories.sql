-- Migration: Update Course Categories
-- Description: Replace old categories (Safety & Regulations, Flight Operations, etc.) 
--              with new categories (Mandatory, Extension, Intermediate, Advanced, Specialized)
-- Created: 2026-01-15

-- ============================================================
-- Step 1: Drop the old constraint first (before updating data)
-- ============================================================

ALTER TABLE public.training_courses 
DROP CONSTRAINT IF EXISTS training_courses_category_check;

-- ============================================================
-- Step 2: Update UAS Pilot course to Mandatory category
-- ============================================================

UPDATE public.training_courses
SET 
    category = 'Mandatory',
    updated_at = NOW()
WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- ============================================================
-- Step 3: Update Flight Review to Mandatory category
-- ============================================================

UPDATE public.training_courses
SET 
    category = 'Mandatory',
    updated_at = NOW()
WHERE id = 'b2c3d4e5-f6a7-8901-bcde-f23456789012';

-- ============================================================
-- Step 4: Update ROC-A Exam to Mandatory category
-- ============================================================

UPDATE public.training_courses
SET 
    category = 'Mandatory',
    updated_at = NOW()
WHERE id = 'c3d4e5f6-a7b8-9012-cdef-345678901234';

-- ============================================================
-- Step 5: Update all specialized courses to Extension category
-- These are the courses that should be in Extension:
-- - Drone Business
-- - Automotive
-- - Real Estate
-- - Motion Picture
-- - Agriculture
-- - Inspections
-- - Search & Rescue
-- - Logistics
-- - Drone Arts
-- - Surveillance and Security
-- - Surveying
-- ============================================================

-- Drone Business
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'f6a7b8c9-d0e1-2345-fabc-678901234567';

-- Automotive
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'a7b8c9d0-e1f2-3456-abcd-789012345678';

-- Real Estate
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'b8c9d0e1-f2a3-4567-bcde-890123456789';

-- Motion Picture
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'c9d0e1f2-a3b4-5678-cdef-901234567890';

-- Agriculture
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'd0e1f2a3-b4c5-6789-defa-012345678901';

-- Inspections
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'e1f2a3b4-c5d6-7890-efab-123456789012';

-- Search & Rescue
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'f2a3b4c5-d6e7-8901-fabc-234567890123';

-- Logistics
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'a3b4c5d6-e7f8-9012-abcd-345678901234';

-- Drone Arts
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'b4c5d6e7-f8a9-0123-bcde-456789012345';

-- Surveillance and Security
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'c5d6e7f8-a9b0-1234-cdef-567890123456';

-- Surveying
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'd6e7f8a9-b0c1-2345-defa-678901234567';

-- ============================================================
-- Step 6: Update Camera/Payload Operator to Extension category
-- (This was previously renamed from Extension Courses)
-- ============================================================

UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE id = 'e5f6a7b8-c9d0-1234-efab-567890123456';

-- ============================================================
-- Step 7: Update any other courses (FAA 107 Recurrent Training, etc.)
-- Set these to Intermediate for now (can be adjusted later)
-- ============================================================

-- FAA 107 Recurrent Training
UPDATE public.training_courses
SET 
    category = 'Intermediate',
    updated_at = NOW()
WHERE id = 'd4e5f6a7-b8c9-0123-defa-456789012345';

-- ============================================================
-- Step 8: Update any remaining courses with old categories to Extension
-- This catches any courses that might have been created with old categories
-- ============================================================

-- Update any remaining courses with old category values to Extension
UPDATE public.training_courses
SET 
    category = 'Extension',
    updated_at = NOW()
WHERE category NOT IN ('Mandatory', 'Extension', 'Intermediate', 'Advanced', 'Specialized');

-- ============================================================
-- Step 9: Add the new constraint (after all data is updated)
-- ============================================================

ALTER TABLE public.training_courses 
ADD CONSTRAINT training_courses_category_check 
CHECK (category = ANY (ARRAY[
    'Mandatory'::text,
    'Extension'::text,
    'Intermediate'::text,
    'Advanced'::text,
    'Specialized'::text
]));

-- ============================================================
-- Summary:
-- ============================================================
-- New category structure:
-- 
-- MANDATORY:
-- - UAS Pilot (a1b2c3d4-e5f6-7890-abcd-ef1234567890)
-- - Flight Review (b2c3d4e5-f6a7-8901-bcde-f23456789012)
-- - ROC-A Exam (c3d4e5f6-a7b8-9012-cdef-345678901234)
--
-- EXTENSION:
-- - Drone Business (f6a7b8c9-d0e1-2345-fabc-678901234567)
-- - Automotive (a7b8c9d0-e1f2-3456-abcd-789012345678)
-- - Real Estate (b8c9d0e1-f2a3-4567-bcde-890123456789)
-- - Motion Picture (c9d0e1f2-a3b4-5678-cdef-901234567890)
-- - Agriculture (d0e1f2a3-b4c5-6789-defa-012345678901)
-- - Inspections (e1f2a3b4-c5d6-7890-efab-123456789012)
-- - Search & Rescue (f2a3b4c5-d6e7-8901-fabc-234567890123)
-- - Logistics (a3b4c5d6-e7f8-9012-abcd-345678901234)
-- - Drone Arts (b4c5d6e7-f8a9-0123-bcde-456789012345)
-- - Surveillance and Security (c5d6e7f8-a9b0-1234-cdef-567890123456)
-- - Surveying (d6e7f8a9-b0c1-2345-defa-678901234567)
-- - Camera/Payload Operator (e5f6a7b8-c9d0-1234-efab-567890123456)
--
-- INTERMEDIATE:
-- - FAA 107 Recurrent Training (d4e5f6a7-b8c9-0123-defa-456789012345)
--
-- ADVANCED:
-- (None currently assigned)
--
-- SPECIALIZED:
-- (None currently assigned)
--
-- ============================================================
-- Verification query:
-- ============================================================
-- SELECT id, title, category FROM public.training_courses 
-- ORDER BY 
--   CASE category 
--     WHEN 'Mandatory' THEN 1 
--     WHEN 'Extension' THEN 2 
--     WHEN 'Intermediate' THEN 3 
--     WHEN 'Advanced' THEN 4 
--     WHEN 'Specialized' THEN 5 
--   END, 
--   title;
