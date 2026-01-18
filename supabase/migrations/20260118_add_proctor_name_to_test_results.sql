-- Migration: Add proctor support for multiple-choice exams
-- This migration adds:
-- 1. needs_proctor column to course_tests table (determines if test requires a proctor)
-- 2. proctor_name column to test_results table (stores the proctor's name)

-- Add needs_proctor column to course_tests table
-- This determines if a test requires proctor supervision
ALTER TABLE public.course_tests
ADD COLUMN IF NOT EXISTS needs_proctor BOOLEAN NOT NULL DEFAULT false;

-- Add comment to document the column
COMMENT ON COLUMN public.course_tests.needs_proctor IS 'Indicates if this test requires supervision by a certified proctor';

-- Add proctor_name column to test_results table
-- This stores the name of the proctor who supervised the exam
ALTER TABLE public.test_results
ADD COLUMN IF NOT EXISTS proctor_name TEXT NULL;

-- Add comment to document the column
COMMENT ON COLUMN public.test_results.proctor_name IS 'Name of the proctor who supervised the exam (for proctored tests only)';

-- Create index for faster queries on proctored tests
CREATE INDEX IF NOT EXISTS idx_test_results_proctor_name 
ON public.test_results (proctor_name) 
WHERE proctor_name IS NOT NULL;
