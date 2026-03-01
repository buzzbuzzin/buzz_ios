-- ============================================================
-- TEMPORARY: Relax storage RLS policies for old app versions
-- ============================================================
-- Old app versions use uppercase UUIDs in storage paths, which
-- can fail the folder-based RLS check. This migration replaces
-- the folder-restricted policies with permissive ones that allow
-- any authenticated user to upload to these buckets.
--
-- Run restore_storage_rls.sql once all users have updated.
-- ============================================================

-- ============================================================
-- 1. profile-pictures
-- ============================================================

DROP POLICY IF EXISTS "Users can upload their own profile picture" ON storage.objects;
CREATE POLICY "Users can upload their own profile picture"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'profile-pictures');

DROP POLICY IF EXISTS "Users can update their own profile picture" ON storage.objects;
CREATE POLICY "Users can update their own profile picture"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'profile-pictures')
WITH CHECK (bucket_id = 'profile-pictures');

DROP POLICY IF EXISTS "Users can delete their own profile picture" ON storage.objects;
CREATE POLICY "Users can delete their own profile picture"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'profile-pictures');

-- Keep SELECT as-is (already public)

-- ============================================================
-- 2. pilot-licenses
-- ============================================================

DROP POLICY IF EXISTS "Pilots can upload their own license files" ON storage.objects;
CREATE POLICY "Pilots can upload their own license files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'pilot-licenses');

DROP POLICY IF EXISTS "Pilots can update their own license files" ON storage.objects;
CREATE POLICY "Pilots can update their own license files"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'pilot-licenses')
WITH CHECK (bucket_id = 'pilot-licenses');

DROP POLICY IF EXISTS "Pilots can delete their own license files" ON storage.objects;
CREATE POLICY "Pilots can delete their own license files"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'pilot-licenses');

-- ============================================================
-- 3. drone-registrations
-- ============================================================

DROP POLICY IF EXISTS "Pilots can upload their own drone registration files" ON storage.objects;
CREATE POLICY "Pilots can upload their own drone registration files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'drone-registrations');

DROP POLICY IF EXISTS "Pilots can update their own drone registration files" ON storage.objects;
CREATE POLICY "Pilots can update their own drone registration files"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'drone-registrations')
WITH CHECK (bucket_id = 'drone-registrations');

DROP POLICY IF EXISTS "Pilots can delete their own drone registration files" ON storage.objects;
CREATE POLICY "Pilots can delete their own drone registration files"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'drone-registrations');

-- ============================================================
-- 4. express-promotion-docs
-- ============================================================

DROP POLICY IF EXISTS "Pilots can upload their own express promotion docs" ON storage.objects;
CREATE POLICY "Pilots can upload their own express promotion docs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'express-promotion-docs');

DROP POLICY IF EXISTS "Pilots can view their own express promotion docs" ON storage.objects;
CREATE POLICY "Pilots can view their own express promotion docs"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'express-promotion-docs');

DROP POLICY IF EXISTS "Pilots can update their own express promotion docs" ON storage.objects;
CREATE POLICY "Pilots can update their own express promotion docs"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'express-promotion-docs')
WITH CHECK (bucket_id = 'express-promotion-docs');

DROP POLICY IF EXISTS "Pilots can delete their own express promotion docs" ON storage.objects;
CREATE POLICY "Pilots can delete their own express promotion docs"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'express-promotion-docs');

-- ============================================================
-- 5. flight-plans (private bucket)
-- ============================================================

DROP POLICY IF EXISTS "Pilots can upload their own flight plan PDFs" ON storage.objects;
CREATE POLICY "Pilots can upload their own flight plan PDFs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'flight-plans');

DROP POLICY IF EXISTS "Pilots can view their own flight plan PDFs" ON storage.objects;
CREATE POLICY "Pilots can view their own flight plan PDFs"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'flight-plans');
