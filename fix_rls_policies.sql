-- Fix RLS Policies for Pilot Licenses and Drone Registrations
-- This migration ensures authenticated users can only see and manage their own files

-- ============================================================================
-- DRONE REGISTRATIONS TABLE
-- ============================================================================

-- Create drone_registrations table if it doesn't exist
CREATE TABLE IF NOT EXISTS drone_registrations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    file_url TEXT NOT NULL,
    file_type TEXT NOT NULL CHECK (file_type IN ('pdf', 'image')),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE drone_registrations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Pilots can view their own drone registrations" ON drone_registrations;
DROP POLICY IF EXISTS "Pilots can insert their own drone registrations" ON drone_registrations;
DROP POLICY IF EXISTS "Pilots can update their own drone registrations" ON drone_registrations;
DROP POLICY IF EXISTS "Pilots can delete their own drone registrations" ON drone_registrations;

-- Drone Registrations RLS Policies
CREATE POLICY "Pilots can view their own drone registrations" 
    ON drone_registrations FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own drone registrations" 
    ON drone_registrations FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can update their own drone registrations" 
    ON drone_registrations FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id)
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can delete their own drone registrations" 
    ON drone_registrations FOR DELETE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Create index for drone_registrations
CREATE INDEX IF NOT EXISTS idx_drone_registrations_pilot_id ON drone_registrations(pilot_id);

-- ============================================================================
-- PILOT LICENSES TABLE - Verify and Fix Policies
-- ============================================================================

-- Ensure RLS is enabled
ALTER TABLE pilot_licenses ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Pilots can view their own licenses" ON pilot_licenses;
DROP POLICY IF EXISTS "Pilots can insert their own licenses" ON pilot_licenses;
DROP POLICY IF EXISTS "Pilots can update their own licenses" ON pilot_licenses;
DROP POLICY IF EXISTS "Pilots can delete their own licenses" ON pilot_licenses;

-- Pilot Licenses RLS Policies (recreate with proper TO authenticated clause)
CREATE POLICY "Pilots can view their own licenses" 
    ON pilot_licenses FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own licenses" 
    ON pilot_licenses FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can update their own licenses" 
    ON pilot_licenses FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id)
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can delete their own licenses" 
    ON pilot_licenses FOR DELETE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- ============================================================================
-- STORAGE BUCKETS
-- ============================================================================

-- Create Storage Bucket for Drone Registrations
INSERT INTO storage.buckets (id, name, public)
VALUES ('drone-registrations', 'drone-registrations', true)
ON CONFLICT (id) DO NOTHING;

-- Ensure pilot-licenses bucket exists (if it doesn't already)
INSERT INTO storage.buckets (id, name, public)
VALUES ('pilot-licenses', 'pilot-licenses', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- STORAGE POLICIES
-- ============================================================================

-- Note: RLS is already enabled on storage.objects by default in Supabase
-- We don't need to enable it explicitly (and can't without superuser privileges)

-- Drop existing storage policies for drone-registrations if they exist
DROP POLICY IF EXISTS "Pilots can upload their own drone registrations" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can view their own drone registrations" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can delete their own drone registrations" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can update their own drone registrations" ON storage.objects;

-- Storage Policies for Drone Registrations
-- Check that the file path starts with the authenticated user's UUID
-- Files are stored as: {pilotId}/{fileName}
-- Note: If storage.foldername() doesn't work, use: split_part(name, '/', 1) = auth.uid()::text
CREATE POLICY "Pilots can upload their own drone registrations"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'drone-registrations' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Pilots can view their own drone registrations"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'drone-registrations' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Pilots can update their own drone registrations"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'drone-registrations' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'drone-registrations' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Pilots can delete their own drone registrations"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'drone-registrations' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Verify and fix storage policies for pilot-licenses
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can upload their own licenses" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can view their own licenses" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can delete their own licenses" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can update their own licenses" ON storage.objects;

-- Storage Policies for Pilot Licenses
-- Check that the file path starts with the authenticated user's UUID
-- Files are stored as: {pilotId}/{fileName}
-- Note: If storage.foldername() doesn't work, use: split_part(name, '/', 1) = auth.uid()::text
CREATE POLICY "Pilots can upload their own licenses"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'pilot-licenses' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Pilots can view their own licenses"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'pilot-licenses' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Pilots can update their own licenses"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'pilot-licenses' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'pilot-licenses' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Pilots can delete their own licenses"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'pilot-licenses' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================================
-- VERIFICATION QUERIES (Optional - uncomment to verify)
-- ============================================================================

-- Verify tables exist and RLS is enabled
-- SELECT tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE schemaname = 'public' 
-- AND tablename IN ('pilot_licenses', 'drone_registrations');

-- Verify policies exist
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies 
-- WHERE tablename IN ('pilot_licenses', 'drone_registrations')
-- ORDER BY tablename, policyname;

-- Verify storage buckets exist
-- SELECT id, name, public 
-- FROM storage.buckets 
-- WHERE id IN ('pilot-licenses', 'drone-registrations');

