-- Migration: Add device tokens table and video upload reminders for push notifications
-- Created: 2024-12-15

-- =============================================================================
-- 1. Device Tokens Table - Stores APNs device tokens for push notifications
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'ios' CHECK (platform = ANY (ARRAY['ios'::text, 'android'::text])),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT device_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT device_tokens_user_token_unique UNIQUE (user_id, token)
);

-- Index for faster lookups by user_id
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);

-- Index for active tokens
CREATE INDEX IF NOT EXISTS idx_device_tokens_active ON public.device_tokens(is_active) WHERE is_active = true;

-- RLS Policies for device_tokens
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Users can view their own device tokens
CREATE POLICY "Users can view own device tokens"
  ON public.device_tokens
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own device tokens
CREATE POLICY "Users can insert own device tokens"
  ON public.device_tokens
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own device tokens
CREATE POLICY "Users can update own device tokens"
  ON public.device_tokens
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own device tokens
CREATE POLICY "Users can delete own device tokens"
  ON public.device_tokens
  FOR DELETE
  USING (auth.uid() = user_id);

-- =============================================================================
-- 2. Video Upload Reminders Table - Tracks sent reminders to prevent duplicates
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.video_upload_reminders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  pilot_id uuid NOT NULL,
  sent_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  reminder_type text NOT NULL DEFAULT '24h' CHECK (reminder_type = ANY (ARRAY['24h'::text, '48h'::text, '72h'::text])),
  CONSTRAINT video_upload_reminders_pkey PRIMARY KEY (id),
  CONSTRAINT video_upload_reminders_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE,
  CONSTRAINT video_upload_reminders_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT video_upload_reminders_booking_type_unique UNIQUE (booking_id, reminder_type)
);

-- Index for faster lookups by booking_id
CREATE INDEX IF NOT EXISTS idx_video_upload_reminders_booking_id ON public.video_upload_reminders(booking_id);

-- Index for faster lookups by pilot_id
CREATE INDEX IF NOT EXISTS idx_video_upload_reminders_pilot_id ON public.video_upload_reminders(pilot_id);

-- RLS Policies for video_upload_reminders
ALTER TABLE public.video_upload_reminders ENABLE ROW LEVEL SECURITY;

-- Service role can manage all reminders (for cron job)
CREATE POLICY "Service role can manage video upload reminders"
  ON public.video_upload_reminders
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- =============================================================================
-- 3. Function to find pilots who need video upload reminders
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_pilots_needing_video_upload_reminder()
RETURNS TABLE (
  booking_id uuid,
  pilot_id uuid,
  pilot_email text,
  completed_at timestamp with time zone,
  hours_since_completion double precision
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id AS booking_id,
    b.pilot_id,
    p.email AS pilot_email,
    b.completed_at,
    EXTRACT(EPOCH FROM (NOW() - b.completed_at)) / 3600 AS hours_since_completion
  FROM public.bookings b
  JOIN public.profiles p ON p.id = b.pilot_id
  WHERE 
    -- Booking is completed
    b.status = 'completed'
    AND b.completed_at IS NOT NULL
    -- Completed more than 24 hours ago
    AND b.completed_at < NOW() - INTERVAL '24 hours'
    -- Completed less than 7 days ago (don't remind for very old bookings)
    AND b.completed_at > NOW() - INTERVAL '7 days'
    -- Pilot exists
    AND b.pilot_id IS NOT NULL
    -- No video uploaded by pilot for this booking
    AND NOT EXISTS (
      SELECT 1 
      FROM public.booking_media_files bmf
      WHERE bmf.booking_id = b.id 
        AND bmf.uploaded_by = b.pilot_id
        AND bmf.role = 'pilot'
    )
    -- No 24h reminder already sent
    AND NOT EXISTS (
      SELECT 1 
      FROM public.video_upload_reminders vur
      WHERE vur.booking_id = b.id
        AND vur.reminder_type = '24h'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 4. Function to record that a reminder was sent
-- =============================================================================

CREATE OR REPLACE FUNCTION public.record_video_upload_reminder(
  p_booking_id uuid,
  p_pilot_id uuid,
  p_reminder_type text DEFAULT '24h'
)
RETURNS uuid AS $$
DECLARE
  reminder_id uuid;
BEGIN
  INSERT INTO public.video_upload_reminders (booking_id, pilot_id, reminder_type)
  VALUES (p_booking_id, p_pilot_id, p_reminder_type)
  ON CONFLICT (booking_id, reminder_type) DO NOTHING
  RETURNING id INTO reminder_id;
  
  RETURN reminder_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 5. Function to get device tokens for a user
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_user_device_tokens(p_user_id uuid)
RETURNS TABLE (
  token text,
  platform text
) AS $$
BEGIN
  RETURN QUERY
  SELECT dt.token, dt.platform
  FROM public.device_tokens dt
  WHERE dt.user_id = p_user_id
    AND dt.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 6. Function to upsert device token
-- =============================================================================

CREATE OR REPLACE FUNCTION public.upsert_device_token(
  p_user_id uuid,
  p_token text,
  p_platform text DEFAULT 'ios'
)
RETURNS uuid AS $$
DECLARE
  token_id uuid;
BEGIN
  INSERT INTO public.device_tokens (user_id, token, platform, is_active, updated_at)
  VALUES (p_user_id, p_token, p_platform, true, NOW())
  ON CONFLICT (user_id, token) 
  DO UPDATE SET 
    is_active = true,
    updated_at = NOW()
  RETURNING id INTO token_id;
  
  RETURN token_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 7. Grant necessary permissions
-- =============================================================================

-- Grant execute on functions to authenticated users
GRANT EXECUTE ON FUNCTION public.upsert_device_token(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_device_tokens(uuid) TO authenticated;

-- Grant execute on functions to service role (for cron job)
GRANT EXECUTE ON FUNCTION public.get_pilots_needing_video_upload_reminder() TO service_role;
GRANT EXECUTE ON FUNCTION public.record_video_upload_reminder(uuid, uuid, text) TO service_role;

-- =============================================================================
-- Note: pg_cron scheduling should be done via Supabase Dashboard or CLI
-- The cron job will call an Edge Function that:
-- 1. Calls get_pilots_needing_video_upload_reminder()
-- 2. For each pilot, sends a push notification via APNs
-- 3. Records the reminder using record_video_upload_reminder()
--
-- To schedule via Supabase Dashboard:
-- SELECT cron.schedule(
--   'check-video-uploads',
--   '0 * * * *',  -- Every hour at minute 0
--   $$SELECT net.http_post(
--     url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/check-video-uploads',
--     headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
--   )$$
-- );
-- =============================================================================

