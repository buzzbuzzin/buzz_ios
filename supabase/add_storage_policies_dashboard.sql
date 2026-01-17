-- ============================================================
-- Storage Policies for course-test-results Bucket
-- Run this in Supabase Dashboard SQL Editor (not via migration CLI)
-- ============================================================

-- Policy 1: Allow pilots to upload files to their own folder
-- Path format: {pilot_id}/{test_id}/{timestamp}_{filename}
CREATE POLICY "Pilots can upload their own test result files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'course-test-results'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Allow pilots to view their own files
CREATE POLICY "Pilots can view their own test result files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'course-test-results'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Allow pilots to update their own files
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

-- Policy 4: Allow pilots to delete their own files
CREATE POLICY "Pilots can delete their own test result files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'course-test-results'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 5: Allow service role full access (for admin review)
CREATE POLICY "Service role can access all test result files"
ON storage.objects
FOR ALL
TO service_role
USING (bucket_id = 'course-test-results')
WITH CHECK (bucket_id = 'course-test-results');

-- Verify policies were created
SELECT schemaname, tablename, policyname, roles, cmd 
FROM pg_policies 
WHERE tablename = 'objects' 
AND policyname LIKE '%test result%';
