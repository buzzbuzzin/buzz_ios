-- Migration: Reorganize course sections for UAS Pilot Course
-- 1. Move Unit 5 from Base Program to Extension Courses
-- 2. Add Flight Review and Radio Operator sections after Base Program
-- 3. Update display_order for existing sections

-- ============================================================
-- Step 1: Update display_order for existing sections to make room
-- ============================================================

-- Move RECURRENT TRAINING from display_order 4 to 6
UPDATE public.course_sections
SET display_order = 6,
    updated_at = timezone('utc'::text, now())
WHERE id = '00000004-0000-0000-0000-000000000004'
  AND course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- Move EXTENSION COURSES from display_order 5 to 7
UPDATE public.course_sections
SET display_order = 7,
    updated_at = timezone('utc'::text, now())
WHERE id = '00000005-0000-0000-0000-000000000005'
  AND course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- Move FURTHER YOUR BASE TRAINING from display_order 6 to 8
UPDATE public.course_sections
SET display_order = 8,
    updated_at = timezone('utc'::text, now())
WHERE id = '00000006-0000-0000-0000-000000000006'
  AND course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- ============================================================
-- Step 2: Insert new sections for Flight Review and Radio Operator
-- ============================================================

-- Insert Flight Review section (display_order: 4, after Base Program)
-- section_type = 'exam' to indicate it links to Test Center exams
INSERT INTO public.course_sections (
    id,
    course_id,
    name,
    display_order,
    description,
    section_type,
    requires_subscription,
    requires_test_passed,
    is_active
)
VALUES (
    '00000007-0000-0000-0000-000000000007',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'FLIGHT REVIEW',
    4,
    'In-person practical flight assessment',
    'exam',  -- New section type for Test Center exams
    false,   -- No subscription required to view
    true,    -- Requires Ground School Test passed
    true
);

-- Insert Radio Operator section (display_order: 5, after Flight Review)
INSERT INTO public.course_sections (
    id,
    course_id,
    name,
    display_order,
    description,
    section_type,
    requires_subscription,
    requires_test_passed,
    is_active
)
VALUES (
    '00000008-0000-0000-0000-000000000008',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'RADIO OPERATOR',
    5,
    'ROC-A radio communication competency certification',
    'exam',  -- New section type for Test Center exams
    false,   -- No subscription required to view
    true,    -- Requires Ground School Test passed
    true
);

-- ============================================================
-- Step 3: Move Unit 5 from Base Program to Extension Courses
-- ============================================================

-- Update Unit 5 to be in Extension Courses section
-- Also update order_index to ensure it appears before Unit 6
UPDATE public.course_units
SET section_id = '00000005-0000-0000-0000-000000000005',  -- Extension Courses section
    step_number = 2,  -- Update deprecated field for backward compatibility
    updated_at = timezone('utc'::text, now())
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
  AND unit_number = 5;

-- ============================================================
-- Step 4: Add exam_type column to course_sections for linking exams
-- ============================================================

-- Add exam_type column to course_sections table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'course_sections' 
        AND column_name = 'exam_type'
    ) THEN
        ALTER TABLE public.course_sections 
        ADD COLUMN exam_type text CHECK (
            exam_type IS NULL OR 
            exam_type = ANY (ARRAY['flight_review'::text, 'roc_a'::text])
        );
    END IF;
END $$;

-- Set exam_type for the new sections
UPDATE public.course_sections
SET exam_type = 'flight_review'
WHERE id = '00000007-0000-0000-0000-000000000007';

UPDATE public.course_sections
SET exam_type = 'roc_a'
WHERE id = '00000008-0000-0000-0000-000000000008';

-- ============================================================
-- Summary of final section structure:
-- ============================================================
-- 1. MANDATORY UNITS (display_order: 1) - Units 1-3
-- 2. GROUND SCHOOL TEST (display_order: 2) - Ground School Test
-- 3. BASE PROGRAM (display_order: 3) - Unit 4 only (Unit 5 moved)
-- 4. FLIGHT REVIEW (display_order: 4) - NEW: Links to Practical Flight Exam
-- 5. RADIO OPERATOR (display_order: 5) - NEW: Links to ROC-A Test
-- 6. RECURRENT TRAINING (display_order: 6) - FAA 107 Recurrent Training
-- 7. EXTENSION COURSES (display_order: 7) - Units 5, 6, 7, 8, 9, 10, 11
-- 8. FURTHER YOUR BASE TRAINING (display_order: 8) - Future units

-- ============================================================
-- Verification query (can be run manually to verify):
-- ============================================================
-- SELECT 
--     cs.display_order,
--     cs.name,
--     cs.section_type,
--     cs.exam_type,
--     COUNT(cu.id) as unit_count
-- FROM public.course_sections cs
-- LEFT JOIN public.course_units cu ON cu.section_id = cs.id
-- WHERE cs.course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
-- GROUP BY cs.id, cs.display_order, cs.name, cs.section_type, cs.exam_type
-- ORDER BY cs.display_order;

