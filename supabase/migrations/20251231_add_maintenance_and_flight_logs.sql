-- Migration: Add maintenance_logs and flight_logs tables
-- Description: Store electronic maintenance and flight log forms for pilots
-- Created: 2025-12-31

-- ============================================
-- MAINTENANCE LOGS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS maintenance_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pilot_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Aircraft Info
    aircraft_number TEXT NOT NULL,
    sheet_number INTEGER NOT NULL DEFAULT 1,
    
    -- Maintenance Entry
    date TIMESTAMPTZ NOT NULL,
    repairs TEXT NOT NULL,
    replacement_parts TEXT,
    comments TEXT,
    
    -- Signature Data (initials stored as base64 PNG image)
    initials_data TEXT NOT NULL,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_locked BOOLEAN DEFAULT TRUE
);

-- Add indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_pilot_id ON maintenance_logs(pilot_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_created_at ON maintenance_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_aircraft_number ON maintenance_logs(aircraft_number);

-- Add RLS policies
ALTER TABLE maintenance_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their maintenance logs" ON maintenance_logs;
DROP POLICY IF EXISTS "Pilots can insert their maintenance logs" ON maintenance_logs;
DROP POLICY IF EXISTS "Maintenance logs cannot be updated once locked" ON maintenance_logs;
DROP POLICY IF EXISTS "Maintenance logs cannot be deleted" ON maintenance_logs;

-- Pilots can view their own maintenance logs
CREATE POLICY "Pilots can view their maintenance logs"
    ON maintenance_logs
    FOR SELECT
    USING (pilot_id = auth.uid());

-- Pilots can insert their own maintenance logs
CREATE POLICY "Pilots can insert their maintenance logs"
    ON maintenance_logs
    FOR INSERT
    WITH CHECK (pilot_id = auth.uid());

-- Prevent updates once locked (submitted)
CREATE POLICY "Maintenance logs cannot be updated once locked"
    ON maintenance_logs
    FOR UPDATE
    USING (FALSE);

-- Pilots cannot delete maintenance logs
CREATE POLICY "Maintenance logs cannot be deleted"
    ON maintenance_logs
    FOR DELETE
    USING (FALSE);

-- ============================================
-- FLIGHT LOGS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS flight_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pilot_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Aircraft Info
    aircraft_number TEXT NOT NULL,
    sheet_number INTEGER NOT NULL DEFAULT 1,
    
    -- Flight Entry
    description_of_flight TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    time_out TIMESTAMPTZ NOT NULL,
    time_in TIMESTAMPTZ NOT NULL,
    total_airtime_minutes INTEGER NOT NULL,
    comments TEXT,
    
    -- Signature Data (stored as base64 PNG image)
    signature_data TEXT NOT NULL,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_locked BOOLEAN DEFAULT TRUE
);

-- Add indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_flight_logs_pilot_id ON flight_logs(pilot_id);
CREATE INDEX IF NOT EXISTS idx_flight_logs_created_at ON flight_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_flight_logs_aircraft_number ON flight_logs(aircraft_number);
CREATE INDEX IF NOT EXISTS idx_flight_logs_date ON flight_logs(date DESC);

-- Add RLS policies
ALTER TABLE flight_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their flight logs" ON flight_logs;
DROP POLICY IF EXISTS "Pilots can insert their flight logs" ON flight_logs;
DROP POLICY IF EXISTS "Flight logs cannot be updated once locked" ON flight_logs;
DROP POLICY IF EXISTS "Flight logs cannot be deleted" ON flight_logs;

-- Pilots can view their own flight logs
CREATE POLICY "Pilots can view their flight logs"
    ON flight_logs
    FOR SELECT
    USING (pilot_id = auth.uid());

-- Pilots can insert their own flight logs
CREATE POLICY "Pilots can insert their flight logs"
    ON flight_logs
    FOR INSERT
    WITH CHECK (pilot_id = auth.uid());

-- Prevent updates once locked (submitted)
CREATE POLICY "Flight logs cannot be updated once locked"
    ON flight_logs
    FOR UPDATE
    USING (FALSE);

-- Pilots cannot delete flight logs
CREATE POLICY "Flight logs cannot be deleted"
    ON flight_logs
    FOR DELETE
    USING (FALSE);

