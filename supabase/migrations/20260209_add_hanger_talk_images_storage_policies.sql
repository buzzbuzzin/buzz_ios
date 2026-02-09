-- ============================================================================
-- Add missing storage RLS policies for hanger_talk_images bucket
-- Migration: 20260209_add_hanger_talk_images_storage_policies.sql
-- Description: The hanger_talk_images bucket was created in the social feed
--              migration but storage RLS policies were never added, blocking
--              all image uploads with a 403 "new row violates row-level
--              security policy" error.
-- ============================================================================

-- Policy: Allow authenticated users to upload images to their own folder
-- Path format: {user_id}/{uuid}.jpg
DROP POLICY IF EXISTS "Users can upload hanger talk images" ON storage.objects;
CREATE POLICY "Users can upload hanger talk images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'hanger_talk_images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow anyone to view hanger talk images (public bucket)
DROP POLICY IF EXISTS "Anyone can view hanger talk images" ON storage.objects;
CREATE POLICY "Anyone can view hanger talk images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'hanger_talk_images');

-- Policy: Allow users to update their own images
DROP POLICY IF EXISTS "Users can update their own hanger talk images" ON storage.objects;
CREATE POLICY "Users can update their own hanger talk images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'hanger_talk_images'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'hanger_talk_images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow users to delete their own images
DROP POLICY IF EXISTS "Users can delete their own hanger talk images" ON storage.objects;
CREATE POLICY "Users can delete their own hanger talk images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'hanger_talk_images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
