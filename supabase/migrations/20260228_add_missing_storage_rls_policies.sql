-- ============================================================
-- Add missing RLS policies for profile-pictures, pilot-licenses,
-- and drone-registrations storage buckets.
--
-- These buckets were created via the dashboard but never had
-- RLS policies added, causing "new row violates row-level
-- security policy" errors on upload.
-- ============================================================

-- ============================================================
-- 1. profile-pictures bucket policies
-- Path format: {user_id}/profile.jpg
-- ============================================================

-- Allow authenticated users to upload to their own folder
CREATE POLICY "Users can upload their own profile picture"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'profile-pictures'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow anyone to view profile pictures (public bucket)
CREATE POLICY "Anyone can view profile pictures"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'profile-pictures');

-- Allow users to update their own profile picture
CREATE POLICY "Users can update their own profile picture"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'profile-pictures'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'profile-pictures'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete their own profile picture
CREATE POLICY "Users can delete their own profile picture"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'profile-pictures'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================
-- 2. pilot-licenses bucket policies
-- Path format: {pilot_id}/{fileName}
-- ============================================================

-- Allow authenticated users to upload to their own folder
CREATE POLICY "Pilots can upload their own license files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'pilot-licenses'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow anyone to view pilot license files (public bucket)
CREATE POLICY "Anyone can view pilot license files"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'pilot-licenses');

-- Allow pilots to update their own license files
CREATE POLICY "Pilots can update their own license files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'pilot-licenses'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'pilot-licenses'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow pilots to delete their own license files
CREATE POLICY "Pilots can delete their own license files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'pilot-licenses'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================
-- 3. drone-registrations bucket policies
-- Path format: {pilot_id}/{fileName}
-- ============================================================

-- Allow authenticated users to upload to their own folder
CREATE POLICY "Pilots can upload their own drone registration files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'drone-registrations'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow anyone to view drone registration files (public bucket)
CREATE POLICY "Anyone can view drone registration files"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'drone-registrations');

-- Allow pilots to update their own drone registration files
CREATE POLICY "Pilots can update their own drone registration files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'drone-registrations'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'drone-registrations'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow pilots to delete their own drone registration files
CREATE POLICY "Pilots can delete their own drone registration files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'drone-registrations'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
