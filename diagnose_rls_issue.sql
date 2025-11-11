-- Diagnostic SQL to identify RLS issues
-- Run this to understand what's blocking your uploads

-- ============================================================================
-- 1. Check if user profile exists (required for foreign key)
-- ============================================================================
-- Replace 'USER_ID_HERE' with the actual user ID from your app
-- You can get this from auth.users table or your app's auth service

SELECT 
    id,
    user_type,
    email,
    first_name,
    last_name
FROM profiles
WHERE id IN (
    SELECT id FROM auth.users 
    ORDER BY created_at DESC 
    LIMIT 5
);

-- ============================================================================
-- 2. Check RLS status on tables
-- ============================================================================

SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('pilot_licenses', 'drone_registrations', 'profiles')
ORDER BY tablename;

-- ============================================================================
-- 3. Check ALL policies on these tables
-- ============================================================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('pilot_licenses', 'drone_registrations', 'profiles')
ORDER BY tablename, policyname;

-- ============================================================================
-- 4. Check storage buckets
-- ============================================================================

SELECT 
    id, 
    name, 
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets 
WHERE id IN ('pilot-licenses', 'drone-registrations');

-- ============================================================================
-- 5. Check storage policies
-- ============================================================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects'
AND (
    policyname LIKE '%drone%' 
    OR policyname LIKE '%license%'
    OR policyname LIKE '%pilot%'
)
ORDER BY policyname;

-- ============================================================================
-- 6. Test: Try to insert a test record (replace with actual user ID)
-- ============================================================================
-- Uncomment and replace USER_ID_HERE with an actual user ID to test

/*
INSERT INTO pilot_licenses (pilot_id, file_url, file_type)
VALUES (
    'USER_ID_HERE'::uuid,
    'https://test.com/file.pdf',
    'pdf'
);
*/

-- ============================================================================
-- 7. Check if RLS is blocking by testing with service role
-- ============================================================================
-- If this works but your app doesn't, it's an RLS/auth issue
-- If this doesn't work, it's a different issue (constraints, etc.)

