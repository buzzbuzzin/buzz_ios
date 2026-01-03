-- Migration: Add Search & Rescue assignment fields to bookings table
-- Description: Adds assignment_type, government_agency, and uses_beacon_program columns for S&R missions
-- Date: 2026-01-02

-- Add new columns to bookings table for S&R missions
ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS assignment_type text CHECK (assignment_type IS NULL OR assignment_type IN ('ground_search', 'air_search', 'water_rescue', 'medical_emergency', 'disaster_response', 'missing_person')),
ADD COLUMN IF NOT EXISTS government_agency text CHECK (government_agency IS NULL OR government_agency IN ('police_department', 'fire_department', 'sheriff_office', 'state_emergency_management')),
ADD COLUMN IF NOT EXISTS uses_beacon_program boolean DEFAULT false;

-- Add comments for documentation
COMMENT ON COLUMN public.bookings.assignment_type IS 'Type of S&R assignment: ground_search, air_search, water_rescue, medical_emergency, disaster_response, missing_person';
COMMENT ON COLUMN public.bookings.government_agency IS 'Government agency for S&R missions: police_department, fire_department, sheriff_office, state_emergency_management';
COMMENT ON COLUMN public.bookings.uses_beacon_program IS 'True if this S&R mission uses Beacon volunteer pilots (government clients only)';

