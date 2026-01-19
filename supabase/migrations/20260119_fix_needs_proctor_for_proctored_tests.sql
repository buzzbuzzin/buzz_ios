-- Migration: Fix needs_proctor for proctored tests
-- Description: Sets needs_proctor = true for tests that require proctor supervision
-- Created: 2026-01-19

-- Update existing tests that should require a proctor
-- This includes oral and practical exams which require in-person supervision

-- Set needs_proctor = true for oral exams (ROC-A)
UPDATE public.course_tests
SET needs_proctor = true
WHERE test_type = 'oral'
  AND needs_proctor = false;

-- Set needs_proctor = true for practical exams (Flight Review)
UPDATE public.course_tests
SET needs_proctor = true
WHERE test_type = 'practical'
  AND needs_proctor = false;

-- For any tests with "(proctor)" in the name, set needs_proctor = true
UPDATE public.course_tests
SET needs_proctor = true
WHERE test_name ILIKE '%proctor%'
  AND needs_proctor = false;

-- Log the updates
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO updated_count
    FROM public.course_tests
    WHERE needs_proctor = true;
    
    RAISE NOTICE 'Updated needs_proctor for proctored tests. Total proctored tests: %', updated_count;
END $$;
