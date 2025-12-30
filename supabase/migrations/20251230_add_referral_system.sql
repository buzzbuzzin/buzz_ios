-- Migration: Add referral/loyalty program system
-- This migration creates tables and fields for the client referral program

-- Add referral_credits field to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS referral_credits numeric DEFAULT 0.0;

-- Add referred_by field to profiles to track who referred this user
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS referred_by uuid REFERENCES public.profiles(id);

-- Create referral_codes table to store unique referral codes for each user
CREATE TABLE IF NOT EXISTS public.referral_codes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL UNIQUE,
  code text NOT NULL UNIQUE,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT referral_codes_pkey PRIMARY KEY (id),
  CONSTRAINT referral_codes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT referral_codes_code_check CHECK (code ~ '^[A-Z0-9]{8}$')
);

-- Create referrals table to track referral relationships
CREATE TABLE IF NOT EXISTS public.referrals (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  referrer_id uuid NOT NULL,
  referee_id uuid NOT NULL UNIQUE,
  referral_code text NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'expired'::text])),
  credit_amount numeric NOT NULL DEFAULT 25.0,
  credited_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT referrals_pkey PRIMARY KEY (id),
  CONSTRAINT referrals_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT referrals_referee_id_fkey FOREIGN KEY (referee_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON public.referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON public.referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referee_id ON public.referrals(referee_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);

-- Enable RLS on new tables
ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- RLS Policies for referral_codes
-- Users can read their own referral code
CREATE POLICY "Users can read their own referral code"
  ON public.referral_codes
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own referral code (via edge function)
CREATE POLICY "Users can insert their own referral code"
  ON public.referral_codes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow anyone to look up a referral code (needed for signup validation)
CREATE POLICY "Anyone can look up referral codes by code"
  ON public.referral_codes
  FOR SELECT
  USING (true);

-- RLS Policies for referrals
-- Users can read referrals where they are the referrer
CREATE POLICY "Users can read their referrals as referrer"
  ON public.referrals
  FOR SELECT
  USING (auth.uid() = referrer_id);

-- Users can read referrals where they are the referee
CREATE POLICY "Users can read their referrals as referee"
  ON public.referrals
  FOR SELECT
  USING (auth.uid() = referee_id);

-- Service role can insert/update referrals (via edge functions)
CREATE POLICY "Service role can manage referrals"
  ON public.referrals
  FOR ALL
  USING (auth.role() = 'service_role');

-- Function to credit referrer when referee completes ID verification
-- This function is called via a database trigger
CREATE OR REPLACE FUNCTION public.credit_referrer_on_verification()
RETURNS TRIGGER AS $$
DECLARE
  referral_record RECORD;
  credit_amount numeric := 25.0;
BEGIN
  -- Only proceed if verification status changed to 'verified'
  IF NEW.verification_status = 'verified' AND 
     (OLD.verification_status IS NULL OR OLD.verification_status != 'verified') THEN
    
    -- Find pending referral for this user
    SELECT * INTO referral_record
    FROM public.referrals
    WHERE referee_id = NEW.user_id
      AND status = 'pending'
    LIMIT 1;
    
    -- If a pending referral exists, credit the referrer
    IF referral_record IS NOT NULL THEN
      -- Update referrer's credits
      UPDATE public.profiles
      SET referral_credits = COALESCE(referral_credits, 0) + credit_amount
      WHERE id = referral_record.referrer_id;
      
      -- Mark referral as completed
      UPDATE public.referrals
      SET status = 'completed',
          credited_at = timezone('utc'::text, now())
      WHERE id = referral_record.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to credit referrer on government ID verification
DROP TRIGGER IF EXISTS trigger_credit_referrer_on_verification ON public.government_ids;
CREATE TRIGGER trigger_credit_referrer_on_verification
  AFTER INSERT OR UPDATE ON public.government_ids
  FOR EACH ROW
  EXECUTE FUNCTION public.credit_referrer_on_verification();

-- Comments for documentation
COMMENT ON TABLE public.referral_codes IS 'Stores unique referral codes for each user in the loyalty program';
COMMENT ON TABLE public.referrals IS 'Tracks referral relationships and credit status';
COMMENT ON COLUMN public.profiles.referral_credits IS 'Available credits earned through referrals, can be applied to bookings';
COMMENT ON COLUMN public.profiles.referred_by IS 'UUID of the user who referred this user';

