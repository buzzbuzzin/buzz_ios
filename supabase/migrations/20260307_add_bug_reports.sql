-- ============================================================================
-- Ticket Reports
-- Migration: 20260307_add_bug_reports.sql
-- Description: Creates the ticket_reports table for users to submit and track
--              tickets (bug reports, etc.) through the Get Help section.
-- ============================================================================

CREATE TABLE IF NOT EXISTS ticket_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'bug' CHECK (type IN ('bug')),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    admin_response TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_ticket_reports_user_id ON ticket_reports(user_id);
CREATE INDEX idx_ticket_reports_status ON ticket_reports(status);
CREATE INDEX idx_ticket_reports_type ON ticket_reports(type);
CREATE INDEX idx_ticket_reports_created_at ON ticket_reports(created_at DESC);

-- Enable RLS
ALTER TABLE ticket_reports ENABLE ROW LEVEL SECURITY;

-- Users can read their own ticket reports
CREATE POLICY "Users can read their own ticket reports"
ON ticket_reports FOR SELECT
USING (auth.uid() = user_id);

-- Users can create ticket reports
CREATE POLICY "Users can create ticket reports"
ON ticket_reports FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Only admins can update ticket reports
CREATE POLICY "Admins can update ticket reports"
ON ticket_reports FOR UPDATE
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

-- Auto-update updated_at on row update
CREATE OR REPLACE FUNCTION update_ticket_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_ticket_reports_updated_at
    BEFORE UPDATE ON ticket_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_ticket_reports_updated_at();
