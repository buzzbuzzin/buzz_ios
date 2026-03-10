-- Migration: Add RLS policy and index for examiner stats feature
-- Allows examiners to view appointments where they were the examiner
-- Adds index on examiner_id for efficient lookups

-- Add index on examiner_id for examiner stats queries
CREATE INDEX IF NOT EXISTS idx_exam_appointments_examiner_id
  ON public.exam_appointments(examiner_id);

-- Allow anyone to read examiner stats (count only, via select on id + exam_type)
-- Examiners need to see rows where they are the examiner_id
DROP POLICY IF EXISTS "Users can view examiner appointments" ON public.exam_appointments;
CREATE POLICY "Users can view examiner appointments"
  ON public.exam_appointments
  FOR SELECT
  USING (auth.uid() = examiner_id);
