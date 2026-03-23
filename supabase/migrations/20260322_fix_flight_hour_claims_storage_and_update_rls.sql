-- Fix two RLS issues with flight_hour_claims:
-- 1. Storage policy missing LOWER() for UUID case-sensitivity (Swift sends uppercase, auth.uid()::text is lowercase)
-- 2. No UPDATE policy for pilots to update their own pending claims (needed for evidence_files after upload)

-- ============================================================
-- 1. Fix storage RLS: add LOWER() to match other bucket policies
-- ============================================================

DROP POLICY IF EXISTS "Pilots can upload evidence files" ON storage.objects;

CREATE POLICY "Pilots can upload evidence files"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'flight-hour-claims'
    AND LOWER((storage.foldername(name))[1]) = auth.uid()::text
  );

-- ============================================================
-- 2. Add pilot UPDATE policy for own pending claims
-- ============================================================

CREATE POLICY "Pilots can update own pending claims"
  ON flight_hour_claims
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = pilot_id AND status = 'pending')
  WITH CHECK (auth.uid() = pilot_id AND status = 'pending');
