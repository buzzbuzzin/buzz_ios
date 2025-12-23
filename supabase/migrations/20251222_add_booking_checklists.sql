-- Migration: Add booking_checklists table
-- Description: Store checklist item states per booking for pre-flight checks
-- Created: 2025-12-22

-- Create booking_checklists table
CREATE TABLE IF NOT EXISTS booking_checklists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    has_insurance BOOLEAN DEFAULT FALSE,
    has_flight_plan BOOLEAN DEFAULT FALSE,
    has_faa_waiver BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(booking_id)
);

-- Add indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_booking_checklists_booking_id ON booking_checklists(booking_id);

-- Add RLS policies
ALTER TABLE booking_checklists ENABLE ROW LEVEL SECURITY;

-- Pilots can view and update checklists for their own bookings
CREATE POLICY "Pilots can view their booking checklists"
    ON booking_checklists
    FOR SELECT
    USING (
        booking_id IN (
            SELECT id FROM bookings WHERE pilot_id = auth.uid()
        )
        OR
        booking_id IN (
            SELECT booking_id FROM booking_crew WHERE pilot_id = auth.uid()
        )
    );

CREATE POLICY "Pilots can insert their booking checklists"
    ON booking_checklists
    FOR INSERT
    WITH CHECK (
        booking_id IN (
            SELECT id FROM bookings WHERE pilot_id = auth.uid()
        )
        OR
        booking_id IN (
            SELECT booking_id FROM booking_crew WHERE pilot_id = auth.uid()
        )
    );

CREATE POLICY "Pilots can update their booking checklists"
    ON booking_checklists
    FOR UPDATE
    USING (
        booking_id IN (
            SELECT id FROM bookings WHERE pilot_id = auth.uid()
        )
        OR
        booking_id IN (
            SELECT booking_id FROM booking_crew WHERE pilot_id = auth.uid()
        )
    );

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_booking_checklists_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_booking_checklists_updated_at
    BEFORE UPDATE ON booking_checklists
    FOR EACH ROW
    EXECUTE FUNCTION update_booking_checklists_updated_at();

-- Add comment
COMMENT ON TABLE booking_checklists IS 'Stores checklist item states for each booking to track pre-flight preparation';

