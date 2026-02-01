-- ============================================================
-- Migration: Add flight_plans table and storage bucket
-- Description: Store flight plan data and PDF files for pilots
-- Date: 2026-02-01
-- ============================================================

-- ============================================================
-- Step 1: Create the flight_plans table
-- ============================================================

CREATE TABLE IF NOT EXISTS flight_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Foreign Keys
    pilot_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    
    -- Flight Details (denormalized for PDF record)
    pilot_name TEXT NOT NULL,
    pilot_license_number TEXT,
    call_sign TEXT NOT NULL,
    drone_manufacturer TEXT,
    drone_model TEXT,
    drone_serial_number TEXT,
    drone_registration_number TEXT,
    takeoff_date_time TIMESTAMPTZ NOT NULL,
    location TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    
    -- Regulatory Section
    regulatory_authority TEXT NOT NULL CHECK (regulatory_authority IN ('FAA', 'TC')),
    max_altitude_feet INTEGER NOT NULL,
    airspace_class TEXT NOT NULL CHECK (airspace_class IN ('B', 'C', 'D', 'E', 'G', 'Unknown')),
    laanc_grid_ceiling INTEGER,
    laanc_authorization_status TEXT NOT NULL CHECK (laanc_authorization_status IN (
        'Auto-Approved',
        'Manual FAA Review Required',
        'No LAANC - Manual Auth Required',
        'Not Permitted Under Part 107',
        'Pending',
        'N/A'
    )),
    
    -- Flight Operations
    flight_over_people BOOLEAN NOT NULL DEFAULT FALSE,
    flight_over_people_explanation TEXT,
    vlos_type TEXT NOT NULL CHECK (vlos_type IN ('VLOS', 'BVLOS')),
    
    -- Part 107 Compliance
    part107_compliant BOOLEAN NOT NULL DEFAULT TRUE,
    part107_non_compliance_explanation TEXT,
    
    -- Waiver Section
    requires_waiver BOOLEAN NOT NULL DEFAULT FALSE,
    waiver_safety_mitigations TEXT,
    waiver_operational_procedures TEXT,
    waiver_risk_analysis TEXT,
    
    -- Certification Section
    certification_regulation TEXT NOT NULL CHECK (certification_regulation IN (
        '14 CFR Part 107',
        '14 CFR Part 108',
        'Part IX TP 15263',
        'Part IX TP 15530'
    )),
    signature_date TIMESTAMPTZ,
    
    -- PDF & Metadata
    pdf_url TEXT NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Step 2: Add indexes for efficient lookups
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_flight_plans_pilot_id ON flight_plans(pilot_id);
CREATE INDEX IF NOT EXISTS idx_flight_plans_booking_id ON flight_plans(booking_id);
CREATE INDEX IF NOT EXISTS idx_flight_plans_created_at ON flight_plans(created_at DESC);

-- ============================================================
-- Step 3: Enable RLS and add table policies
-- ============================================================

ALTER TABLE flight_plans ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own flight plans" ON flight_plans;
DROP POLICY IF EXISTS "Pilots can insert their own flight plans" ON flight_plans;
DROP POLICY IF EXISTS "Flight plans cannot be updated" ON flight_plans;
DROP POLICY IF EXISTS "Flight plans cannot be deleted" ON flight_plans;

-- Pilots can view their own flight plans
CREATE POLICY "Pilots can view their own flight plans"
    ON flight_plans
    FOR SELECT
    USING (pilot_id = auth.uid());

-- Pilots can insert their own flight plans
CREATE POLICY "Pilots can insert their own flight plans"
    ON flight_plans
    FOR INSERT
    WITH CHECK (pilot_id = auth.uid());

-- Flight plans cannot be updated (immutable record)
CREATE POLICY "Flight plans cannot be updated"
    ON flight_plans
    FOR UPDATE
    USING (FALSE);

-- Flight plans cannot be deleted
CREATE POLICY "Flight plans cannot be deleted"
    ON flight_plans
    FOR DELETE
    USING (FALSE);

-- ============================================================
-- Step 4: Create the storage bucket for flight plan PDFs
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'flight-plans',
    'flight-plans',
    false, -- Private bucket
    10485760, -- 10MB file size limit
    ARRAY['application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['application/pdf'];

-- ============================================================
-- Step 5: Add storage RLS policies
-- ============================================================

-- Note: RLS is already enabled on storage.objects by Supabase

-- Policy: Allow pilots to upload their own flight plan PDFs
-- Path format: {pilot_id}/{booking_id}/{timestamp}_flight_plan.pdf
DROP POLICY IF EXISTS "Pilots can upload their own flight plan PDFs" ON storage.objects;
CREATE POLICY "Pilots can upload their own flight plan PDFs"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'flight-plans'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow pilots to view their own flight plan PDFs
DROP POLICY IF EXISTS "Pilots can view their own flight plan PDFs" ON storage.objects;
CREATE POLICY "Pilots can view their own flight plan PDFs"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'flight-plans'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow service role to access all flight plan files (for admin)
DROP POLICY IF EXISTS "Service role can access all flight plan files" ON storage.objects;
CREATE POLICY "Service role can access all flight plan files"
ON storage.objects
FOR ALL
TO service_role
USING (bucket_id = 'flight-plans')
WITH CHECK (bucket_id = 'flight-plans');

-- ============================================================
-- NOTES
-- ============================================================
-- 
-- Table: flight_plans
-- - Stores all flight plan form data
-- - Links to pilot via pilot_id and booking via booking_id
-- - Immutable record (no updates or deletes allowed)
-- - pdf_url stores the path to the uploaded PDF in storage
--
-- Storage Bucket: flight-plans
-- - Private bucket for flight plan PDFs
-- - Path Structure: {pilot_id}/{booking_id}/{timestamp}_flight_plan.pdf
-- - 10MB file size limit, PDF only
--
-- ============================================================
