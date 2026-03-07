-- ============================================================
-- Add image support to bug reports
-- ============================================================

-- 1. Add image_urls column
ALTER TABLE ticket_reports ADD COLUMN IF NOT EXISTS image_urls TEXT[] DEFAULT '{}';

-- 2. Create storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('bug-report-images', 'bug-report-images', true, 10485760,
        ARRAY['image/jpeg','image/png','image/heic','image/heif'])
ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg','image/png','image/heic','image/heif'];

-- 3. Storage RLS policies

-- INSERT: users can upload to their own folder
DROP POLICY IF EXISTS "Users can upload bug report images" ON storage.objects;
CREATE POLICY "Users can upload bug report images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'bug-report-images'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);

-- SELECT: public bucket, anyone can view
DROP POLICY IF EXISTS "Bug report images are publicly viewable" ON storage.objects;
CREATE POLICY "Bug report images are publicly viewable"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'bug-report-images');

-- UPDATE: users can update their own files
DROP POLICY IF EXISTS "Users can update their own bug report images" ON storage.objects;
CREATE POLICY "Users can update their own bug report images"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'bug-report-images'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'bug-report-images'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);

-- No DELETE policy: submitted bug report images should not be deletable by users
-- to preserve evidence. Admins can delete via service-role if needed.
