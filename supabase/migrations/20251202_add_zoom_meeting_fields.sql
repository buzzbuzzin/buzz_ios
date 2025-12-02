-- Migration: Add Zoom meeting fields to exam_appointments table
-- These fields store Zoom meeting details for online ROC-A exams

-- Add zoom_meeting_id column to store the Zoom meeting ID
ALTER TABLE public.exam_appointments
ADD COLUMN IF NOT EXISTS zoom_meeting_id text;

-- Add zoom_meeting_password column to store the meeting password
ALTER TABLE public.exam_appointments
ADD COLUMN IF NOT EXISTS zoom_meeting_password text;

-- Add comments for documentation
COMMENT ON COLUMN public.exam_appointments.zoom_meeting_id IS 'Zoom meeting ID for online exams, used for meeting management';
COMMENT ON COLUMN public.exam_appointments.zoom_meeting_password IS 'Zoom meeting password for online exams';

-- Create index on zoom_meeting_id for potential lookups
CREATE INDEX IF NOT EXISTS idx_exam_appointments_zoom_meeting_id 
ON public.exam_appointments(zoom_meeting_id) 
WHERE zoom_meeting_id IS NOT NULL;

