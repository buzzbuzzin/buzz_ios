-- Migration: Update Course Titles
-- Description: Updates course titles for ROC-A and Part 107 Recurrent Training
-- Created: 2026-01-15

-- ============================================================
-- Step 1: Update ROC-A Exam title to ROC-A
-- ============================================================

UPDATE public.training_courses
SET 
    title = 'ROC-A',
    updated_at = NOW()
WHERE id = 'c3d4e5f6-a7b8-9012-cdef-345678901234';

-- ============================================================
-- Step 2: Update FAA 107 Recurrent Training to Part 107 Recurrent Training
-- ============================================================

UPDATE public.training_courses
SET 
    title = 'Part 107 Recurrent Training',
    updated_at = NOW()
WHERE id = 'd4e5f6a7-b8c9-0123-defa-456789012345';

-- ============================================================
-- Step 3: Update exam_type_config display names
-- ============================================================

UPDATE public.exam_type_config
SET 
    display_name = 'ROC-A',
    updated_at = NOW()
WHERE exam_type = 'roc_a';

-- Verification queries (optional)
-- SELECT id, title FROM public.training_courses WHERE id IN ('c3d4e5f6-a7b8-9012-cdef-345678901234', 'd4e5f6a7-b8c9-0123-defa-456789012345');
-- SELECT exam_type, display_name FROM public.exam_type_config WHERE exam_type = 'roc_a';
