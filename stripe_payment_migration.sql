-- Stripe Payment Migration Script
-- Run this SQL in your Supabase SQL Editor to add support for Stripe payments

-- Add Stripe account ID to profiles table (for pilots)
DO $$ 
BEGIN
    -- Add stripe_account_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'stripe_account_id'
    ) THEN
        ALTER TABLE profiles ADD COLUMN stripe_account_id TEXT;
    END IF;
END $$;

-- Add payment fields to bookings table
DO $$ 
BEGIN
    -- Add payment_intent_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'payment_intent_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN payment_intent_id TEXT;
    END IF;
    
    -- Add transfer_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'transfer_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN transfer_id TEXT;
    END IF;
    
    -- Add charge_id if it doesn't exist (from PaymentIntent's latest_charge)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'charge_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN charge_id TEXT;
    END IF;
END $$;

-- Create indexes for payment fields
CREATE INDEX IF NOT EXISTS idx_bookings_payment_intent_id ON bookings(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_bookings_transfer_id ON bookings(transfer_id);
CREATE INDEX IF NOT EXISTS idx_profiles_stripe_account_id ON profiles(stripe_account_id);

-- Add comments for documentation
COMMENT ON COLUMN profiles.stripe_account_id IS 'Stripe Connect account ID for pilots (acct_xxx)';
COMMENT ON COLUMN bookings.payment_intent_id IS 'Stripe PaymentIntent ID (pi_xxx)';
COMMENT ON COLUMN bookings.transfer_id IS 'Stripe Transfer ID (tr_xxx) - created when booking is completed';
COMMENT ON COLUMN bookings.charge_id IS 'Stripe Charge ID (ch_xxx) - from PaymentIntent latest_charge';

