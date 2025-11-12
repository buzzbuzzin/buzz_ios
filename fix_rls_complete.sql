-- Complete Fix for RLS Policies - Run this to completely fix the issue
-- This script will:
-- 1. Drop ALL existing policies
-- 2. Create permissive policies that work
-- 3. Ensure storage buckets and policies are set up correctly

-- ============================================================================
-- STEP 1: Drop ALL existing policies on pilot_licenses
-- ============================================================================

DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'pilot_licenses') 
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON pilot_licenses';
    END LOOP;
END $$;

-- ============================================================================
-- STEP 2: Drop ALL existing policies on drone_registrations
-- ============================================================================

DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'drone_registrations') 
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON drone_registrations';
    END LOOP;
END $$;

-- ============================================================================
-- STEP 3: Ensure tables exist
-- ============================================================================

CREATE TABLE IF NOT EXISTS drone_registrations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    file_url TEXT NOT NULL,
    file_type TEXT NOT NULL CHECK (file_type IN ('pdf', 'image')),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- ============================================================================
-- STEP 4: Create VERY PERMISSIVE policies (for testing)
-- ============================================================================

-- Enable RLS
ALTER TABLE pilot_licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE drone_registrations ENABLE ROW LEVEL SECURITY;

-- Pilot Licenses - Allow ANY authenticated user to do ANYTHING
-- This is very permissive - tighten later once you confirm it works
CREATE POLICY "Allow authenticated users full access to pilot_licenses"
    ON pilot_licenses
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Drone Registrations - Allow ANY authenticated user to do ANYTHING  
CREATE POLICY "Allow authenticated users full access to drone_registrations"
    ON drone_registrations
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================================================
-- STEP 5: Create indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_drone_registrations_pilot_id ON drone_registrations(pilot_id);
CREATE INDEX IF NOT EXISTS idx_pilot_licenses_pilot_id ON pilot_licenses(pilot_id);

-- ============================================================================
-- STEP 6: Storage Buckets
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('drone-registrations', 'drone-registrations', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('pilot-licenses', 'pilot-licenses', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- STEP 7: Drop ALL existing storage policies
-- ============================================================================

DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'storage' 
        AND tablename = 'objects'
        AND (
            policyname LIKE '%drone%' 
            OR policyname LIKE '%license%'
            OR policyname LIKE '%pilot%'
        )
    ) 
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON storage.objects';
    END LOOP;
END $$;

-- ============================================================================
-- STEP 8: Create VERY PERMISSIVE storage policies
-- ============================================================================

-- Allow ANY authenticated user to upload to pilot-licenses bucket
CREATE POLICY "Allow authenticated uploads to pilot-licenses"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'pilot-licenses');

CREATE POLICY "Allow authenticated access to pilot-licenses"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (bucket_id = 'pilot-licenses');

CREATE POLICY "Allow authenticated updates to pilot-licenses"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (bucket_id = 'pilot-licenses')
    WITH CHECK (bucket_id = 'pilot-licenses');

CREATE POLICY "Allow authenticated deletes to pilot-licenses"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (bucket_id = 'pilot-licenses');

-- Allow ANY authenticated user to upload to drone-registrations bucket
CREATE POLICY "Allow authenticated uploads to drone-registrations"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'drone-registrations');

CREATE POLICY "Allow authenticated access to drone-registrations"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (bucket_id = 'drone-registrations');

CREATE POLICY "Allow authenticated updates to drone-registrations"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (bucket_id = 'drone-registrations')
    WITH CHECK (bucket_id = 'drone-registrations');

CREATE POLICY "Allow authenticated deletes to drone-registrations"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (bucket_id = 'drone-registrations');

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check RLS status
SELECT 
    tablename, 
    rowsecurity as rls_enabled 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('pilot_licenses', 'drone_registrations');

-- Check policies
SELECT 
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE tablename IN ('pilot_licenses', 'drone_registrations')
ORDER BY tablename, policyname;

-- Check storage buckets
SELECT id, name, public 
FROM storage.buckets 
WHERE id IN ('pilot-licenses', 'drone-registrations');

-- Check storage policies
SELECT 
    policyname,
    cmd
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects'
AND (
    policyname LIKE '%drone%' 
    OR policyname LIKE '%license%'
)
ORDER BY policyname;

