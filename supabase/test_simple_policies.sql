-- ============================================================
-- STEP 1: First, let's update bucket to be PRIVATE (not PUBLIC)
-- ============================================================
UPDATE storage.buckets 
SET public = false 
WHERE id = 'course-test-results';

-- ============================================================
-- STEP 2: Drop existing policies and create simpler ones for testing
-- ============================================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Pilots can delete their own test result files" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can update their own test result files" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can upload their own test result files" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can view their own test result files" ON storage.objects;
DROP POLICY IF EXISTS "Service role can access all test result files" ON storage.objects;

-- Create a VERY permissive policy first to test if auth is working at all
-- This allows ANY authenticated user to upload to the bucket
CREATE POLICY "Test: Allow all authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'course-test-results'
);

-- Allow authenticated users to view all files in this bucket (for testing)
CREATE POLICY "Test: Allow all authenticated reads"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'course-test-results'
);

-- Service role policy (admin access)
CREATE POLICY "Service role full access"
ON storage.objects
FOR ALL
TO service_role
USING (bucket_id = 'course-test-results')
WITH CHECK (bucket_id = 'course-test-results');

-- Verify policies
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'objects' 
AND policyname LIKE '%Test%';
