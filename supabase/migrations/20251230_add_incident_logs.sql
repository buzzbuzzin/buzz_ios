-- Migration: Add incident_logs table
-- Description: Store electronic incident log forms for pilots
-- Created: 2025-12-30

-- Create incident_logs table
CREATE TABLE IF NOT EXISTS incident_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    pilot_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Basic Information
    name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    date_of_incident TIMESTAMPTZ NOT NULL,
    date_of_report TIMESTAMPTZ NOT NULL,
    job_title TEXT,
    operation_name TEXT,
    organization TEXT,
    pic TEXT, -- Pilot in Command
    region TEXT,
    airspace_class TEXT,
    reported_to_police BOOLEAN DEFAULT FALSE,
    reported_to_atc BOOLEAN DEFAULT FALSE,
    
    -- Incident Details
    location_of_incident TEXT NOT NULL,
    description_of_incident TEXT NOT NULL,
    name_of_witness TEXT,
    
    -- Signature Data (stored as base64 PNG image)
    signature_data TEXT NOT NULL,
    signature_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_locked BOOLEAN DEFAULT TRUE, -- Once submitted, cannot be modified
    
    UNIQUE(booking_id, pilot_id)
);

-- Add indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_incident_logs_booking_id ON incident_logs(booking_id);
CREATE INDEX IF NOT EXISTS idx_incident_logs_pilot_id ON incident_logs(pilot_id);
CREATE INDEX IF NOT EXISTS idx_incident_logs_created_at ON incident_logs(created_at DESC);

-- Add RLS policies
ALTER TABLE incident_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their incident logs" ON incident_logs;
DROP POLICY IF EXISTS "Pilots can insert their incident logs" ON incident_logs;
DROP POLICY IF EXISTS "Incident logs cannot be updated once locked" ON incident_logs;
DROP POLICY IF EXISTS "Incident logs cannot be deleted" ON incident_logs;

-- Pilots can view their own incident logs
CREATE POLICY "Pilots can view their incident logs"
    ON incident_logs
    FOR SELECT
    USING (pilot_id = auth.uid());

-- Pilots can insert their own incident logs
CREATE POLICY "Pilots can insert their incident logs"
    ON incident_logs
    FOR INSERT
    WITH CHECK (pilot_id = auth.uid());

-- Prevent updates once locked (submitted)
CREATE POLICY "Incident logs cannot be updated once locked"
    ON incident_logs
    FOR UPDATE
    USING (FALSE);

-- Pilots cannot delete incident logs
CREATE POLICY "Incident logs cannot be deleted"
    ON incident_logs
    FOR DELETE
    USING (FALSE);

