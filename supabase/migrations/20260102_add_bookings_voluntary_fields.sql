-- Migration: Add voluntary mission fields to bookings table
-- Description: Adds is_voluntary, hourly_rate, and final_hours_worked columns for Search & Rescue missions
-- Date: 2026-01-02

-- Add new columns to bookings table if they don't already exist
ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS is_voluntary boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS hourly_rate numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS final_hours_worked double precision;

-- Add comments for documentation
COMMENT ON COLUMN public.bookings.is_voluntary IS 'True if this is a voluntary mission with no payment to pilots';
COMMENT ON COLUMN public.bookings.hourly_rate IS 'Hourly rate per pilot for S&R missions (typically $25)';
COMMENT ON COLUMN public.bookings.final_hours_worked IS 'Actual hours worked, entered by client after mission completion';

