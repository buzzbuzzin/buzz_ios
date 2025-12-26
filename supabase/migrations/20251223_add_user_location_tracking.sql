-- Migration: Add location tracking to profiles table
-- Created: 2025-12-23
-- Description: Adds last_location_lat, last_location_lng, and last_location_update columns to profiles table for tracking user locations

-- Add location columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_location_lat double precision,
ADD COLUMN IF NOT EXISTS last_location_lng double precision,
ADD COLUMN IF NOT EXISTS last_location_update timestamp with time zone;

-- Add comment to document the purpose
COMMENT ON COLUMN public.profiles.last_location_lat IS 'Last known latitude of the user when they opened the app';
COMMENT ON COLUMN public.profiles.last_location_lng IS 'Last known longitude of the user when they opened the app';
COMMENT ON COLUMN public.profiles.last_location_update IS 'Timestamp when the location was last updated';

-- Create index on last_location_update for efficient queries
CREATE INDEX IF NOT EXISTS idx_profiles_last_location_update ON public.profiles(last_location_update);

