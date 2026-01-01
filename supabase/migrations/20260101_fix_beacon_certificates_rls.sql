-- Migration: Fix Beacon Certificates RLS - Disable restrictive policies
-- Description: Allow all authenticated users to upload certificates

-- Drop all existing certificate storage policies
DROP POLICY IF EXISTS "Users can upload own certificates" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own certificates" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own certificates" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own certificates" ON storage.objects;
DROP POLICY IF EXISTS "Public can view certificates" ON storage.objects;

-- Make certificates bucket public
UPDATE storage.buckets 
SET public = true 
WHERE id = 'certificates';

-- Simple permissive policies for certificates bucket
CREATE POLICY "Allow authenticated uploads to certificates"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'certificates');

CREATE POLICY "Allow public read certificates"
    ON storage.objects
    FOR SELECT
    TO public
    USING (bucket_id = 'certificates');

CREATE POLICY "Allow authenticated update certificates"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (bucket_id = 'certificates');

CREATE POLICY "Allow authenticated delete certificates"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (bucket_id = 'certificates');

-- Disable RLS on beacon_training_progress completely
ALTER TABLE public.beacon_training_progress DISABLE ROW LEVEL SECURITY;
