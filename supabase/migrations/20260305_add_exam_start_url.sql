-- Migration: Add start_url column to exam_appointments for examiner host link
-- The start_url gives the examiner host privileges when joining the Zoom meeting

ALTER TABLE public.exam_appointments
ADD COLUMN IF NOT EXISTS start_url text;

COMMENT ON COLUMN public.exam_appointments.start_url IS 'Zoom start URL for the examiner/host to join with host privileges';
