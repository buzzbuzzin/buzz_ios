-- Add image_urls array column to hangar_posts
ALTER TABLE hangar_posts ADD COLUMN IF NOT EXISTS image_urls text[] DEFAULT '{}';

-- ============================================================
-- Create the storage bucket for hangar post images
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'hanger_images',
    'hanger_images',
    true, -- Public bucket so images can be viewed via public URL
    10485760, -- 10MB file size limit
    ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/heif'];

-- ============================================================
-- Add storage RLS policies for hanger_images bucket
-- ============================================================

-- Policy: Allow authenticated users to upload images to their own folder
-- Path format: {user_id}/{uuid}.jpg
DROP POLICY IF EXISTS "Users can upload hangar post images" ON storage.objects;
CREATE POLICY "Users can upload hangar post images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'hanger_images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow anyone to view hangar post images (public bucket)
DROP POLICY IF EXISTS "Anyone can view hangar post images" ON storage.objects;
CREATE POLICY "Anyone can view hangar post images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'hanger_images');

-- Policy: Allow users to update their own images
DROP POLICY IF EXISTS "Users can update their own hangar post images" ON storage.objects;
CREATE POLICY "Users can update their own hangar post images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'hanger_images'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'hanger_images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow users to delete their own images
DROP POLICY IF EXISTS "Users can delete their own hangar post images" ON storage.objects;
CREATE POLICY "Users can delete their own hangar post images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'hanger_images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
