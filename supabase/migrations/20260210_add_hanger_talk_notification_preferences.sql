-- Add Hanger Talk notification preference columns
ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS hanger_talk_likes_system BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS hanger_talk_likes_email BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hanger_talk_likes_text BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hanger_talk_replies_system BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS hanger_talk_replies_email BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hanger_talk_replies_text BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hanger_talk_mentions_system BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS hanger_talk_mentions_email BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hanger_talk_mentions_text BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hanger_talk_follows_system BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS hanger_talk_follows_email BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hanger_talk_follows_text BOOLEAN NOT NULL DEFAULT false;
