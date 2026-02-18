-- ============================================================================
-- App Version Tracking
-- Migration: 20260218_add_app_version_tracking.sql
-- Description: Creates a table to track which app version and platform each
--              user is running. One row per user, upserted on each app launch.
-- ============================================================================

CREATE TABLE IF NOT EXISTS app_version_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    platform TEXT NOT NULL,
    app_version TEXT NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id)
);

CREATE INDEX idx_app_version_tracking_user
    ON app_version_tracking(user_id);
CREATE INDEX idx_app_version_tracking_version
    ON app_version_tracking(app_version);
CREATE INDEX idx_app_version_tracking_last_seen
    ON app_version_tracking(last_seen_at DESC);

ALTER TABLE app_version_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can upsert own version tracking"
    ON app_version_tracking FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own version tracking"
    ON app_version_tracking FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY "Users can view own version tracking"
    ON app_version_tracking FOR SELECT
    USING (user_id = auth.uid());
