-- Fix case-sensitivity: Swift .uuidString is UPPERCASE but auth.uid()::text is lowercase.
-- Use LOWER() so both existing uppercase paths and future lowercase paths work.

-- ============================================================
-- 1. profile-pictures
-- ============================================================

DROP POLICY IF EXISTS "Users can upload their own profile picture" ON storage.objects;
CREATE POLICY "Users can upload their own profile picture"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'profile-pictures'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can update their own profile picture" ON storage.objects;
CREATE POLICY "Users can update their own profile picture"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'profile-pictures' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text)
WITH CHECK (bucket_id = 'profile-pictures' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete their own profile picture" ON storage.objects;
CREATE POLICY "Users can delete their own profile picture"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'profile-pictures' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text);

-- ============================================================
-- 2. pilot-licenses
-- ============================================================

DROP POLICY IF EXISTS "Pilots can upload their own license files" ON storage.objects;
CREATE POLICY "Pilots can upload their own license files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'pilot-licenses'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);

DROP POLICY IF EXISTS "Pilots can update their own license files" ON storage.objects;
CREATE POLICY "Pilots can update their own license files"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'pilot-licenses' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text)
WITH CHECK (bucket_id = 'pilot-licenses' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text);

DROP POLICY IF EXISTS "Pilots can delete their own license files" ON storage.objects;
CREATE POLICY "Pilots can delete their own license files"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'pilot-licenses' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text);

-- ============================================================
-- 3. drone-registrations
-- ============================================================

DROP POLICY IF EXISTS "Pilots can upload their own drone registration files" ON storage.objects;
CREATE POLICY "Pilots can upload their own drone registration files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'drone-registrations'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);

DROP POLICY IF EXISTS "Pilots can update their own drone registration files" ON storage.objects;
CREATE POLICY "Pilots can update their own drone registration files"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'drone-registrations' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text)
WITH CHECK (bucket_id = 'drone-registrations' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text);

DROP POLICY IF EXISTS "Pilots can delete their own drone registration files" ON storage.objects;
CREATE POLICY "Pilots can delete their own drone registration files"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'drone-registrations' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text);

-- ============================================================
-- 4. express-promotion-docs
-- ============================================================

DROP POLICY IF EXISTS "Pilots can upload their own express promotion docs" ON storage.objects;
CREATE POLICY "Pilots can upload their own express promotion docs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'express-promotion-docs'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);

DROP POLICY IF EXISTS "Pilots can view their own express promotion docs" ON storage.objects;
CREATE POLICY "Pilots can view their own express promotion docs"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'express-promotion-docs'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
);

DROP POLICY IF EXISTS "Pilots can update their own express promotion docs" ON storage.objects;
CREATE POLICY "Pilots can update their own express promotion docs"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'express-promotion-docs' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text)
WITH CHECK (bucket_id = 'express-promotion-docs' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text);

DROP POLICY IF EXISTS "Pilots can delete their own express promotion docs" ON storage.objects;
CREATE POLICY "Pilots can delete their own express promotion docs"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'express-promotion-docs' AND LOWER((storage.foldername(name))[1]) = auth.uid()::text);
