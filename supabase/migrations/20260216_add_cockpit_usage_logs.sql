-- ============================================================================
-- Cockpit Usage Logs
-- Migration: 20260216_add_cockpit_usage_logs.sql
-- Description: Creates a table to log cockpit component usage for analytics.
--              Tracks which components users interact with and in which section.
-- ============================================================================

CREATE TABLE IF NOT EXISTS cockpit_usage_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    component_name TEXT NOT NULL,
    section_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cockpit_usage_logs_user_created
    ON cockpit_usage_logs(user_id, created_at DESC);
CREATE INDEX idx_cockpit_usage_logs_component_created
    ON cockpit_usage_logs(component_name, created_at DESC);
CREATE INDEX idx_cockpit_usage_logs_section
    ON cockpit_usage_logs(section_name);

ALTER TABLE cockpit_usage_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own usage logs"
    ON cockpit_usage_logs FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view own usage logs"
    ON cockpit_usage_logs FOR SELECT
    USING (user_id = auth.uid());
