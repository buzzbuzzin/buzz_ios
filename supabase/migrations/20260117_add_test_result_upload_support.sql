-- ============================================================
-- Migration: Add Test Result Upload Support
-- Description: Add fields to test_results table to support file uploads
--              for non-multiple-choice exams (Flight Review, ROC-A)
-- Date: 2026-01-17
-- ============================================================

-- Add new columns to test_results table
ALTER TABLE public.test_results
ADD COLUMN IF NOT EXISTS result_file_urls TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS upload_status TEXT DEFAULT 'not_submitted' CHECK (upload_status IN ('not_submitted', 'pending', 'approved', 'rejected')),
ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS reviewer_notes TEXT,
ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id);

-- Create index for faster queries on upload_status
CREATE INDEX IF NOT EXISTS idx_test_results_upload_status 
ON public.test_results(upload_status);

-- Create index for faster queries on pending uploads
CREATE INDEX IF NOT EXISTS idx_test_results_pending_uploads 
ON public.test_results(pilot_id, upload_status) 
WHERE upload_status = 'pending';

COMMENT ON COLUMN public.test_results.result_file_urls IS 'Array of URLs to uploaded test result files in Supabase Storage';
COMMENT ON COLUMN public.test_results.upload_status IS 'Status of uploaded test results: not_submitted, pending, approved, rejected';
COMMENT ON COLUMN public.test_results.uploaded_at IS 'Timestamp when the test result files were uploaded';
COMMENT ON COLUMN public.test_results.reviewed_at IS 'Timestamp when the uploaded results were reviewed by admin';
COMMENT ON COLUMN public.test_results.reviewer_notes IS 'Admin notes about the test result review';
COMMENT ON COLUMN public.test_results.reviewed_by IS 'ID of the admin who reviewed the test results';

-- ============================================================
-- Update RLS Policies
-- ============================================================

-- Policy: Pilots can view their own test results
DROP POLICY IF EXISTS "Pilots can view their own test results" ON public.test_results;
CREATE POLICY "Pilots can view their own test results"
ON public.test_results
FOR SELECT
TO authenticated
USING (pilot_id = auth.uid());

-- Policy: Pilots can insert their own test results
DROP POLICY IF EXISTS "Pilots can insert their own test results" ON public.test_results;
CREATE POLICY "Pilots can insert their own test results"
ON public.test_results
FOR INSERT
TO authenticated
WITH CHECK (pilot_id = auth.uid());

-- Policy: Pilots can update their own test results (for uploads)
DROP POLICY IF EXISTS "Pilots can update their own test results" ON public.test_results;
CREATE POLICY "Pilots can update their own test results"
ON public.test_results
FOR UPDATE
TO authenticated
USING (pilot_id = auth.uid())
WITH CHECK (pilot_id = auth.uid());

-- ============================================================
-- Create function to handle test result uploads
-- ============================================================

CREATE OR REPLACE FUNCTION public.submit_test_result_upload(
    p_pilot_id UUID,
    p_test_id UUID,
    p_course_id UUID,
    p_file_urls TEXT[]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result_id UUID;
BEGIN
    -- Insert or update test result with uploaded files
    INSERT INTO public.test_results (
        pilot_id,
        test_id,
        course_id,
        score,
        passed,
        result_file_urls,
        upload_status,
        uploaded_at,
        attempt_number
    )
    VALUES (
        p_pilot_id,
        p_test_id,
        p_course_id,
        0, -- Score is 0 until reviewed
        false, -- Not passed until approved
        p_file_urls,
        'pending',
        NOW(),
        1
    )
    ON CONFLICT (pilot_id, test_id)
    DO UPDATE SET
        result_file_urls = p_file_urls,
        upload_status = 'pending',
        uploaded_at = NOW(),
        attempt_number = test_results.attempt_number + 1
    RETURNING id INTO v_result_id;
    
    RETURN v_result_id;
END;
$$;

-- ============================================================
-- Create function to approve test result (admin only)
-- ============================================================

CREATE OR REPLACE FUNCTION public.approve_test_result(
    p_result_id UUID,
    p_reviewer_id UUID,
    p_score INTEGER,
    p_reviewer_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.test_results
    SET
        upload_status = 'approved',
        passed = true,
        score = p_score,
        reviewed_at = NOW(),
        reviewed_by = p_reviewer_id,
        reviewer_notes = p_reviewer_notes
    WHERE id = p_result_id;
    
    RETURN FOUND;
END;
$$;

-- ============================================================
-- Create function to reject test result (admin only)
-- ============================================================

CREATE OR REPLACE FUNCTION public.reject_test_result(
    p_result_id UUID,
    p_reviewer_id UUID,
    p_reviewer_notes TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.test_results
    SET
        upload_status = 'rejected',
        passed = false,
        reviewed_at = NOW(),
        reviewed_by = p_reviewer_id,
        reviewer_notes = p_reviewer_notes
    WHERE id = p_result_id;
    
    RETURN FOUND;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.submit_test_result_upload TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_test_result TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_test_result TO authenticated;
