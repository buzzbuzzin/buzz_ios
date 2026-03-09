-- Dedicated in-app notification table for license approval events.
-- Mirrors the pattern of hanger_talk_notifications but scoped to license workflow.

CREATE TABLE IF NOT EXISTS public.license_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('pre_approved', 'approved', 'rejected')),
    license_id UUID REFERENCES public.pilot_licenses(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast unread queries
CREATE INDEX idx_license_notifications_recipient_unread
    ON public.license_notifications (recipient_id, created_at DESC)
    WHERE is_read = FALSE;

-- Index for general listing
CREATE INDEX idx_license_notifications_recipient
    ON public.license_notifications (recipient_id, created_at DESC);

-- RLS
ALTER TABLE public.license_notifications ENABLE ROW LEVEL SECURITY;

-- Pilots can read their own notifications
CREATE POLICY license_notifications_select ON public.license_notifications
    FOR SELECT USING (auth.uid() = recipient_id);

-- Pilots can mark their own notifications as read
CREATE POLICY license_notifications_update ON public.license_notifications
    FOR UPDATE USING (auth.uid() = recipient_id)
    WITH CHECK (auth.uid() = recipient_id);

-- Service role inserts (edge function uses service role key)
-- No INSERT policy needed for authenticated users since only the edge function inserts.
-- The edge function uses SUPABASE_SERVICE_ROLE_KEY which bypasses RLS.
