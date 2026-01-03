-- Migration: Add number_of_pilots column and fire_emergency assignment type
-- Description: Adds number_of_pilots for S&R missions and updates assignment_type to include fire_emergency
-- Date: 2026-01-03

-- Add number_of_pilots column
ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS number_of_pilots integer DEFAULT 1;

-- Drop and recreate the assignment_type constraint to include fire_emergency
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_assignment_type_check;
ALTER TABLE public.bookings 
ADD CONSTRAINT bookings_assignment_type_check 
CHECK (assignment_type IS NULL OR assignment_type IN ('ground_search', 'air_search', 'water_rescue', 'medical_emergency', 'fire_emergency', 'disaster_response', 'missing_person'));

-- Add comments for documentation
COMMENT ON COLUMN public.bookings.number_of_pilots IS 'Number of pilots requested for S&R missions (default 1)';
COMMENT ON COLUMN public.bookings.assignment_type IS 'Type of S&R assignment: ground_search, air_search, water_rescue, medical_emergency, fire_emergency, disaster_response, missing_person';

