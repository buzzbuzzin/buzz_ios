-- ============================================================
-- Add missing RLS policies for express-promotion-docs,
-- presentations, and SOP storage buckets.
-- ============================================================

-- ============================================================
-- 1. express-promotion-docs bucket policies (private bucket)
-- Path format: {pilot_id}/{uuid}_{fileName}
-- ============================================================

-- Allow authenticated users to upload to their own folder
CREATE POLICY "Pilots can upload their own express promotion docs"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'express-promotion-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to view their own documents
CREATE POLICY "Pilots can view their own express promotion docs"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'express-promotion-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to update their own documents
CREATE POLICY "Pilots can update their own express promotion docs"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'express-promotion-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'express-promotion-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to delete their own documents
CREATE POLICY "Pilots can delete their own express promotion docs"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'express-promotion-docs'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow service role full access for admin review
CREATE POLICY "Service role can access all express promotion docs"
ON storage.objects
FOR ALL
TO service_role
USING (bucket_id = 'express-promotion-docs')
WITH CHECK (bucket_id = 'express-promotion-docs');

-- ============================================================
-- 2. presentations bucket policies (public, read-only content)
-- ============================================================

-- Allow anyone to view presentations (public bucket)
CREATE POLICY "Anyone can view presentations"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'presentations');

-- ============================================================
-- 3. SOP bucket policies (public, read-only content)
-- ============================================================

-- Allow anyone to view SOP documents (public bucket)
CREATE POLICY "Anyone can view SOP documents"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'SOP');
