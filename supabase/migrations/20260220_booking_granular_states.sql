-- ============================================================================
-- Booking Granular States
-- Migration: 20260220_booking_granular_states.sql
-- Description: Adds new booking statuses (staffed, in_progress, expired) and
--              expiration tracking columns to the bookings table.
-- ============================================================================

-- Drop the existing status CHECK constraint and recreate with new values
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;

ALTER TABLE bookings ADD CONSTRAINT bookings_status_check
    CHECK (status IN ('available', 'accepted', 'staffed', 'in_progress', 'completed', 'expired', 'cancelled'));

-- Add expiration tracking columns
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS expiration_notified BOOLEAN DEFAULT false;
