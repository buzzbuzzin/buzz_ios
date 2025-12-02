-- Migration: Update RLS policy to allow cancelling both pending and confirmed appointments

-- Drop the existing policy
DROP POLICY IF EXISTS "Pilots can update own pending exam appointments" ON public.exam_appointments;

-- Create updated policy that allows updating pending OR confirmed appointments
CREATE POLICY "Pilots can update own pending or confirmed exam appointments"
  ON public.exam_appointments
  FOR UPDATE
  USING (
    auth.uid() = pilot_id 
    AND status IN ('pending', 'confirmed')
  )
  WITH CHECK (auth.uid() = pilot_id);

-- Add comment for documentation
COMMENT ON POLICY "Pilots can update own pending or confirmed exam appointments" ON public.exam_appointments 
  IS 'Allows pilots to update (cancel) their own pending or confirmed appointments';

