-- ============================================================================
-- Hanger Talk Notifications (Inbox)
-- Migration: 20260210_add_hanger_talk_notifications_table.sql
-- Description: Creates a table to store in-app notification events for the
--              Hanger Talk inbox (likes, replies, mentions, follows, new posts).
-- ============================================================================

CREATE TABLE IF NOT EXISTS hanger_talk_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('like', 'reply', 'mention', 'follow', 'new_post')),
    post_id UUID REFERENCES hanger_talk_posts(id) ON DELETE CASCADE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hanger_talk_notifications_recipient_created
    ON hanger_talk_notifications(recipient_id, created_at DESC);
CREATE INDEX idx_hanger_talk_notifications_recipient_unread
    ON hanger_talk_notifications(recipient_id, is_read) WHERE is_read = FALSE;

ALTER TABLE hanger_talk_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
    ON hanger_talk_notifications FOR SELECT
    USING (recipient_id = auth.uid());

CREATE POLICY "Users can insert notifications as actor"
    ON hanger_talk_notifications FOR INSERT
    WITH CHECK (actor_id = auth.uid());

CREATE POLICY "Users can mark own notifications as read"
    ON hanger_talk_notifications FOR UPDATE
    USING (recipient_id = auth.uid())
    WITH CHECK (recipient_id = auth.uid());
