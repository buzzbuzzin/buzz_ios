-- ============================================================
-- Migration: Add Storage Policies for Test Results Bucket
-- Description: Configure RLS policies for course-test-results storage bucket
--              to allow pilots to upload and view their own test result files
-- Date: 2026-01-17
-- ============================================================

-- ============================================================
-- Step 1: Create the storage bucket if it doesn't exist
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'course-test-results',
    'course-test-results',
    false, -- Private bucket
    10485760, -- 10MB file size limit
    ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/heif', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/heif', 'application/pdf'];

-- ============================================================
-- Step 2: Enable RLS on storage.objects table (should already be enabled)
-- ============================================================

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Step 3: Create RLS policies for the course-test-results bucket
-- ============================================================

-- Policy 1: Allow authenticated users to INSERT/UPLOAD files to their own folder
-- Path format: {pilot_id}/{test_id}/{timestamp}_{filename}
DROP POLICY IF EXISTS "Pilots can upload their own test result files" ON storage.objects;
CREATE POLICY "Pilots can upload their own test result files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'course-test-results'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Allow authenticated users to SELECT/VIEW their own files
DROP POLICY IF EXISTS "Pilots can view their own test result files" ON storage.objects;
CREATE POLICY "Pilots can view their own test result files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'course-test-results'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Allow authenticated users to UPDATE their own files (for metadata updates)
DROP POLICY IF EXISTS "Pilots can update their own test result files" ON storage.objects;
CREATE POLICY "Pilots can update their own test result files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'course-test-results'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'course-test-results'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Allow authenticated users to DELETE their own files (before final submission)
DROP POLICY IF EXISTS "Pilots can delete their own test result files" ON storage.objects;
CREATE POLICY "Pilots can delete their own test result files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'course-test-results'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================
-- Step 4: Create admin policies (optional - for admin portal)
-- ============================================================

-- Policy 5: Allow service role to access all files (for admin review)
DROP POLICY IF EXISTS "Service role can access all test result files" ON storage.objects;
CREATE POLICY "Service role can access all test result files"
ON storage.objects
FOR ALL
TO service_role
USING (bucket_id = 'course-test-results')
WITH CHECK (bucket_id = 'course-test-results');

-- ============================================================
-- Verification Query
-- ============================================================

-- Check that policies are created
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE '%test result%';

-- ============================================================
-- NOTES
-- ============================================================
-- 
-- Path Structure: {pilot_id}/{test_id}/{timestamp}_{filename}
-- Example: 123e4567-e89b-12d3-a456-426614174000/f1a2b3c4-d5e6-7890-abcd-f11ab0000001/1705564800_result.pdf
--
-- The (storage.foldername(name))[1] extracts the first folder from the path,
-- which should be the pilot_id. This ensures pilots can only access their own files.
--
-- File Size Limit: 10MB per file
-- Allowed MIME Types: JPEG, PNG, HEIC, HEIF, PDF
--
-- ============================================================
