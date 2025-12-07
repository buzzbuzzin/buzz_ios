-- Migration: Add email_change_tokens table for email verification flow
-- This table stores verification tokens for email change requests

-- Create email_change_tokens table
CREATE TABLE IF NOT EXISTS public.email_change_tokens (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  old_email text NOT NULL,
  new_email text NOT NULL,
  token text NOT NULL,
  verified boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  expires_at timestamp with time zone NOT NULL,
  CONSTRAINT email_change_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT email_change_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Ensure token is 6 digits
  CONSTRAINT email_change_tokens_token_check CHECK (token ~ '^\d{6}$')
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_email_change_tokens_user_id ON public.email_change_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_email_change_tokens_token ON public.email_change_tokens(token);
CREATE INDEX IF NOT EXISTS idx_email_change_tokens_verified ON public.email_change_tokens(verified);
CREATE INDEX IF NOT EXISTS idx_email_change_tokens_expires_at ON public.email_change_tokens(expires_at);

-- Enable Row Level Security
ALTER TABLE public.email_change_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users can view their own email change tokens
CREATE POLICY "Users can view own email change tokens"
  ON public.email_change_tokens
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can create their own email change tokens (via edge function)
CREATE POLICY "Users can create own email change tokens"
  ON public.email_change_tokens
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens (for verification)
CREATE POLICY "Users can update own email change tokens"
  ON public.email_change_tokens
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Function to clean up expired tokens (can be run periodically)
CREATE OR REPLACE FUNCTION public.cleanup_expired_email_tokens()
RETURNS void AS $$
BEGIN
  DELETE FROM public.email_change_tokens
  WHERE expires_at < timezone('utc'::text, now())
    AND verified = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment for documentation
COMMENT ON TABLE public.email_change_tokens IS 'Stores 6-digit verification tokens for email change requests with 30-minute expiration';
COMMENT ON COLUMN public.email_change_tokens.token IS '6-digit numeric verification code';
COMMENT ON COLUMN public.email_change_tokens.verified IS 'Whether the token has been successfully verified';
COMMENT ON COLUMN public.email_change_tokens.expires_at IS 'Token expiration timestamp (30 minutes from creation)';

