-- ============================================================================
-- Integrate Booking Disputes into Ticket Reports
-- Migration: 20260313_integrate_disputes_into_tickets.sql
-- Description: Adds booking_id and reason columns to ticket_reports,
--              migrates data from booking_disputes, drops old table,
--              and updates RLS policies.
-- ============================================================================

-- 1. Add new columns
ALTER TABLE ticket_reports ADD COLUMN booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE;
ALTER TABLE ticket_reports ADD COLUMN reason TEXT;

-- 2. Update type constraint to allow 'dispute'
ALTER TABLE ticket_reports DROP CONSTRAINT IF EXISTS ticket_reports_type_check;
ALTER TABLE ticket_reports ADD CONSTRAINT ticket_reports_type_check CHECK (type IN ('bug', 'safety', 'dispute'));

-- 3. Migrate existing disputes
INSERT INTO ticket_reports (id, user_id, type, title, description, status, admin_response, image_urls, booking_id, reason, created_at, updated_at)
SELECT
    id,
    initiated_by,
    'dispute',
    CASE reason
        WHEN 'incorrect_charge' THEN 'Incorrect Charge'
        WHEN 'service_not_provided' THEN 'Service Not Provided'
        WHEN 'quality_issue' THEN 'Quality Issue'
        WHEN 'safety_concern' THEN 'Safety Concern'
        WHEN 'other' THEN 'Other'
        ELSE initcap(replace(reason, '_', ' '))
    END,
    COALESCE(description, ''),
    CASE status
        WHEN 'open' THEN 'open'
        WHEN 'under_review' THEN 'in_progress'
        WHEN 'resolved' THEN 'resolved'
        WHEN 'dismissed' THEN 'closed'
        ELSE 'open'
    END,
    resolution,
    '{}',
    booking_id,
    reason,
    created_at,
    COALESCE(resolved_at, created_at)
FROM booking_disputes;

-- 4. Drop old table
DROP TABLE booking_disputes;

-- 5. Update RLS: replace INSERT policy to enforce booking ownership for disputes
DROP POLICY IF EXISTS "Users can create ticket reports" ON ticket_reports;

CREATE POLICY "Users can create ticket reports"
ON ticket_reports FOR INSERT
WITH CHECK (
    auth.uid() = user_id
    AND (
        type != 'dispute'
        OR (
            booking_id IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM bookings
                WHERE bookings.id = ticket_reports.booking_id
                AND (bookings.customer_id = auth.uid() OR bookings.pilot_id = auth.uid())
            )
        )
    )
);

-- 6. Index for looking up disputes by booking
CREATE INDEX idx_ticket_reports_booking_id ON ticket_reports(booking_id) WHERE booking_id IS NOT NULL;
