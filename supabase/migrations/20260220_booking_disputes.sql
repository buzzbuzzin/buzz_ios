-- ============================================================================
-- Booking Disputes
-- Migration: 20260220_booking_disputes.sql
-- Description: Creates the booking_disputes table for handling disputes
--              between customers and pilots on completed or in-progress bookings.
-- ============================================================================

CREATE TABLE IF NOT EXISTS booking_disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    initiated_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved', 'dismissed')),
    resolution TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

-- Index for looking up disputes by booking
CREATE INDEX idx_booking_disputes_booking_id ON booking_disputes(booking_id);

-- Enable RLS
ALTER TABLE booking_disputes ENABLE ROW LEVEL SECURITY;

-- Users can create disputes for bookings where they are the customer or pilot
CREATE POLICY "Users can create disputes for their bookings"
ON booking_disputes FOR INSERT
WITH CHECK (
    auth.uid() = initiated_by
    AND EXISTS (
        SELECT 1 FROM bookings
        WHERE bookings.id = booking_disputes.booking_id
        AND (bookings.customer_id = auth.uid() OR bookings.pilot_id = auth.uid())
    )
);

-- Users can read disputes for bookings where they are the customer or pilot
CREATE POLICY "Users can read disputes for their bookings"
ON booking_disputes FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM bookings
        WHERE bookings.id = booking_disputes.booking_id
        AND (bookings.customer_id = auth.uid() OR bookings.pilot_id = auth.uid())
    )
);

-- Only admins (service role) can update dispute status/resolution
CREATE POLICY "Admins can update disputes"
ON booking_disputes FOR UPDATE
USING (
    auth.uid() IN (
        SELECT id FROM profiles WHERE role = 'admin'
    )
)
WITH CHECK (
    auth.uid() IN (
        SELECT id FROM profiles WHERE role = 'admin'
    )
);
